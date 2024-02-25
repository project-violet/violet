// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

// refer: https://github.com/vinhjaxt/rust-DPI-http-proxy/blob/master/src/main.rs

#![deny(warnings)]
use futures_util::future::try_join;
use std::{future::Future, time::Duration};
use tokio_io_timeout::TimeoutReader;

use std::collections::HashMap;

use async_std::sync::{Arc, RwLock};
use flutter_rust_bridge::for_generated::lazy_static;
use hyper::{client::HttpConnector, upgrade::Upgraded};
use hyper::{Body, Client, Method, Request, Response};
use hyper_tls::HttpsConnector;
use std::net::{IpAddr, SocketAddr, ToSocketAddrs};
use tokio::io::{self, AsyncRead, AsyncWrite};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use twoway::find_bytes;

#[derive(Clone)]
struct CacheResolver {
    map: Arc<RwLock<HashMap<String, IpAddr>>>,
}

impl CacheResolver {
    pub async fn get(&self, k: &String) -> Option<IpAddr> {
        match self.map.read().await.get(k) {
            None => None,
            Some(v) => Some(*v),
        }
    }
    pub async fn set(&self, k: String, v: IpAddr) {
        self.map.write().await.insert(k, v);
    }
}

lazy_static! {
    static ref HTTP_CLIENT: Client<HttpConnector> = {
        Client::builder()
            .pool_idle_timeout(Duration::from_secs(60))
            .pool_max_idle_per_host(20)
            .http1_title_case_headers(true)
            .build_http()
    };
    static ref HTTPS_CLIENT: Client<HttpsConnector<HttpConnector>> = {
        let https = HttpsConnector::new();
        Client::builder()
            .pool_idle_timeout(Duration::from_secs(60))
            .pool_max_idle_per_host(20)
            .http1_title_case_headers(true)
            .build::<_, hyper::Body>(https)
    };
    static ref IP_CACHE: CacheResolver = {
        CacheResolver {
            map: Arc::new(RwLock::new(HashMap::new())),
        }
    };
}

type HttpClient = Client<HttpConnector>;
type HttpsClient = Client<HttpsConnector<hyper::client::HttpConnector>>;

static mut DOH_ENDPOINT: &'static str = "https://1.1.1.1/dns-query";
static mut CONNECT_TIMEOUT: u64 = 5;
static mut READ_TIMEOUT: u64 = 0;
static mut DISABLED_DOH: bool = false;
static mut INSERT_SPACE_HTTP_HOST: bool = false;
static SPACE_HTTP_HOST: &'static [u8] = &[32];

async fn proxy(mut req: Request<Body>) -> Result<Response<Body>, hyper::Error> {
    let http_client = HTTP_CLIENT.clone();
    let https_client = HTTPS_CLIENT.clone();

    if Method::CONNECT == req.method() {
        let uri = req.uri().to_owned();
        tokio::task::spawn(async move {
            match req.into_body().on_upgrade().await {
                Ok(upgraded) => {
                    tunnel(upgraded, &uri, https_client).await;
                }
                Err(e) => eprintln!("upgrade error: {}", e),
            }
        });

        Ok(Response::new(Body::empty()))
    } else {
        let req_headers = req.headers_mut();
        if unsafe { INSERT_SPACE_HTTP_HOST } {
            // Change host
            let host = req_headers.get(hyper::header::HOST).unwrap().as_bytes();
            let host_new = [SPACE_HTTP_HOST, host].concat();
            req_headers.insert(
                hyper::header::HOST,
                hyper::header::HeaderValue::from_bytes(host_new.as_slice()).unwrap(),
            );
            req_headers.insert(
                hyper::header::CONNECTION,
                hyper::header::HeaderValue::from_static("close"),
            );
        }
        req_headers.remove("proxy-connection");
        http_client.request(req).await
    }
}

async fn split_hello_phrase<'a, R, W>(
    reader: &'a mut R,
    writer: &'a mut W,
    hostname: &[u8],
) -> std::io::Result<()>
where
    R: AsyncRead + Unpin + ?Sized,
    W: AsyncWrite + Unpin + ?Sized,
{
    let mut hello_buf = [0; 1024];
    let n = reader.read(&mut hello_buf).await?;
    let i = find_bytes(&hello_buf, hostname);
    if i.is_none() {
        writer.write(&hello_buf[0..n]).await?;
    } else {
        let middle_hostname = hostname.len() / 2 + i.unwrap();
        writer.write(&hello_buf[0..middle_hostname]).await?;
        writer.write(&hello_buf[middle_hostname..n]).await?;
    }
    Ok(())
}

async fn tunnel(
    upgraded: Upgraded,
    uri: &http::Uri,
    https_client: HttpsClient,
) -> std::io::Result<()> {
    let Some((mut server, hostname)) = get_server_connection(uri, https_client).await else {
        return Ok(());
    };

    // Proxying data
    let amounts = {
        let (mut server_rd, mut server_wr) = server.split();
        let (client_rd, mut client_wr) = tokio::io::split(upgraded);

        // timeout(Duration::from_secs(unsafe { READ_TIMEOUT }), client_rd);
        let mut client_rd_timeout = TimeoutReader::new(client_rd);
        if unsafe { READ_TIMEOUT } != 0 {
            client_rd_timeout.set_timeout(Some(Duration::from_secs(unsafe { READ_TIMEOUT })));
        }
        split_hello_phrase(&mut client_rd_timeout, &mut server_wr, hostname).await?;
        let server_to_client = tokio::io::copy(&mut server_rd, &mut client_wr);
        let client_to_server = tokio::io::copy(&mut client_rd_timeout, &mut server_wr);
        try_join(client_to_server, server_to_client).await
    };

    // Print message when done
    match amounts {
        Ok((_from_client, _from_server)) => {
            // println!("client wrote {} bytes and received {} bytes", from_client, from_server);
        }
        Err(_e) => {
            // println!("{} tunnel error: {}", std::str::from_utf8(hostname).unwrap(), e);
        }
    };
    // println!("CLOSED {}", std::str::from_utf8(hostname).unwrap());
    server.shutdown(std::net::Shutdown::Both)?;
    // server.shutdown();
    Ok(())
}

async fn get_server_connection<'a>(
    uri: &'a http::Uri,
    https_client: HttpsClient,
) -> Option<(TcpStream, &'a [u8])> {
    let conn_timeout = Some(Duration::from_secs(unsafe { CONNECT_TIMEOUT }));
    let auth = uri.authority()?;
    let host = auth.host();
    let host_bytes = host.as_bytes();
    let host_string = host.to_owned();
    let port: u16 = match auth.port() {
        None => 443,
        Some(p) => p.as_u16(),
    };
    // cache
    if let Some(ip) = IP_CACHE.get(&host_string).await {
        let s = do_timeout(TcpStream::connect(SocketAddr::new(ip, port)), conn_timeout).await;
        if s.is_ok() {
            return Some((s.unwrap(), host_bytes));
        }
    }
    // if can not connect to cache one, system dns
    let sock_addr = auth.as_str().to_socket_addrs();
    if sock_addr.is_ok() {
        for mut addr in sock_addr.unwrap() {
            addr.set_port(port);
            let s = do_timeout(TcpStream::connect(addr), conn_timeout).await;
            if s.is_ok() {
                // save to cache
                IP_CACHE.set(host_string, addr.ip()).await;
                return Some((s.unwrap(), host_bytes));
            }
        }
    }

    if unsafe { DISABLED_DOH } {
        return None;
    }
    // if system dns not resolved, do doh
    let req = Request::get(format!(
        "{}?ct=application/dns-json&type=A&name={}",
        unsafe { DOH_ENDPOINT },
        host_string
    ))
    .header(
        "Accept",
        "application/dns-json, application/json, text/plain, */*",
    )
    .body(Body::empty())
    .unwrap();
    let resp = https_client.request(req).await;
    if resp.is_err() {
        println!("dns-over-https: {} {}", resp.err()?, host);
        return None;
    }
    let body = hyper::body::to_bytes(resp.unwrap().body_mut()).await;
    if body.is_err() {
        return None;
    }
    let json = ajson::parse(&std::str::from_utf8(body.unwrap().as_ref()).unwrap())?;
    for ans in &json.get("Answer")?.to_vec() {
        let data = (*ans).get("data");
        if data.is_none() {
            continue;
        }
        let addr = (data.unwrap().as_str(), port)
            .to_socket_addrs()
            .unwrap()
            .next()?;
        let s = do_timeout(TcpStream::connect(addr), conn_timeout).await;
        if s.is_ok() {
            // save to cache
            IP_CACHE.set(host_string, addr.ip()).await;
            return Some((s.unwrap(), host_bytes));
        }
    }
    None
}

async fn do_timeout<T, F>(f: F, timeout: Option<Duration>) -> Result<T, std::io::Error>
where
    F: Future<Output = Result<T, std::io::Error>>,
{
    if let Some(to) = timeout {
        match tokio::time::timeout(to, f).await {
            Err(_elapsed) => Err(io::Error::new(io::ErrorKind::TimedOut, "timeout")),
            Ok(Ok(try_res)) => Ok(try_res),
            Ok(Err(e)) => Err(e),
        }
    } else {
        f.await
    }
}

#[cfg(not(windows))]
fn set_max_rlimit_nofile() {
    if rlimit::Resource::NOFILE
        .set(rlimit::RLIM_INFINITY, rlimit::RLIM_INFINITY)
        .is_ok()
    {
        println!("Set rlimit ok");
    }
}

#[cfg(test)]
mod tests {
    fn unittest_proxy() -> eyre::Result<()> {
        Ok(())
    }
}
