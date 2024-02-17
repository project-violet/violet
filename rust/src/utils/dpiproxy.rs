// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

// refer: https://github.com/vinhjaxt/rust-DPI-http-proxy/blob/master/src/main.rs

use std::time::Duration;

use flutter_rust_bridge::for_generated::lazy_static;
use hyper::{client::HttpConnector, Body, Client, Method, Request};
use hyper_tls::HttpsConnector;

type HttpClient = Client<hyper::client::HttpConnector>;
type HttpsClient = Client<HttpsConnector<hyper::client::HttpConnector>>;

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
}

async fn proxy(mut req: Request<Body>) {
    let http_client = HTTP_CLIENT.clone();
    let https_client = HTTPS_CLIENT.clone();
}
