// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

extern crate futures;
extern crate futures_cpupool;
extern crate hyper; // 0.12
extern crate hyper_rustls;

use http::StatusCode;
use std::collections::HashMap;
use std::os::raw::{c_char};
use std::ffi::{CString, CStr};
use std::thread;
use std::time::Duration;
use std::sync::{Arc, Mutex};
use std::sync::atomic::{AtomicUsize, Ordering};
// use hyper::rt::Stream;
use hyper::{Body, Client, Request};
use hyper_rustls::HttpsConnector;
use futures_util::StreamExt;
// use reqwest::header::Headers;
// use std::sync::mpsc::channel;
// use std::rc::Rc;
use serde::{Deserialize, Serialize};
use tokio::runtime::Runtime;
// use reqwest::{StatusCode};
use reqwest::header::{HeaderMap, HeaderName};
use std::io;
use std::fs::File;
use serde_json::json;
use futures::Future;
use futures_cpupool::CpuPool;
use hyper::body::HttpBody as _;
use hyper_native_tls::NativeTlsClient;
use tokio::io::{stdout, AsyncWriteExt as _};

extern crate concurrent_queue;
use concurrent_queue::ConcurrentQueue;

#[macro_use]
extern crate lazy_static;

#[no_mangle]
pub extern fn rust_greeting(to: *const c_char) -> *mut c_char {
  let c_str = unsafe { CStr::from_ptr(to) };
  let recipient = match c_str.to_str() {
    Err(_) => "there",
    Ok(string) => string,
  };
  CString::new("Hello ".to_owned() + recipient).unwrap().into_raw()
}

// Download Info
static DOWNLOAD_TOTAL_COUNT: i32 = 0;
static DOWNLOAD_COMPLETED_COUNT: i64 = 0;
static DOWNLOADED_BYTES: i64 = 0;
static DOWNLOAD_ERROR_COUNT: AtomicUsize = AtomicUsize::new(0);
static mut DOWNLOADER_DISPOSED: bool = false;
// static mut ERROR_INFO: Vec<i32> = Vec::new();
static mut DOWNLOAD_THREAD: Vec<thread::JoinHandle<()>> = Vec::new();

// struct DownloadTask<'a> {
//   id: i64,
//   url: &'a str,
//   fullpath: &'a str,
//   header: HashMap<&'a str, &'a str>,
// }

#[derive(Serialize, Deserialize)]
struct DownloadTask {
  id: i64,
  url: String,
  fullpath: String,
  header: HashMap<String, serde_json::Value>,
}

lazy_static! {
  static ref DOWNLOAD_QUEUE: ConcurrentQueue<DownloadTask> = {
    ConcurrentQueue::unbounded()
  };
  static ref DOWNLOAD_LOCK: Arc<Mutex<i32>> = {
    Arc::new(Mutex::new(0))
  };
  static ref DOWNLOAD_THREAD_POOL: CpuPool = CpuPool::new(4);
}

#[no_mangle]
pub extern fn downloader_init(queue_size: i64) {
  unsafe {
    for x in 0..queue_size {
      DOWNLOAD_THREAD.push(thread::spawn(move || {
        Runtime::new()
          .expect("Failed to create Tokio runtime").
          block_on(remote_download_handler(x));
      }));
    }
  }
}

#[no_mangle]
pub extern fn downloader_dispose() {
  unsafe {
    DOWNLOADER_DISPOSED = true;
  }
}

#[no_mangle]
pub extern fn downloader_status() -> *mut c_char {
  CString::new(format!("{}|{}|{}|{}", 
    DOWNLOAD_TOTAL_COUNT.to_string(), 
    DOWNLOAD_COMPLETED_COUNT, 
    DOWNLOADED_BYTES, 
    DOWNLOAD_ERROR_COUNT.load(Ordering::SeqCst))).unwrap().into_raw()
}

#[no_mangle]
pub extern fn downloader_append(to: *const c_char) {
  let c_str = unsafe { CStr::from_ptr(to) };
  let info = match c_str.to_str() {
    Err(_) => "",
    Ok(string) => string,
  };

  if info.len() == 0 {
    return;
  }

  let task: DownloadTask = serde_json::from_str(info).unwrap();
  DOWNLOAD_QUEUE.push(task).ok();
  // DOWNLOAD_THREAD_POOL.spawn(move || {
  //       Runtime::new()
  //         .expect("Failed to create Tokio runtime").
  //         block_on(download(task.url, task.fullpath, task.header));
  //     });
}

async fn download(url: String, fullpath: String, header: HashMap<String, serde_json::Value>) -> Result<i64, reqwest::Error> {
  let mut task = tokio::fs::File::create(fullpath).await.unwrap();
  let client = reqwest::Client::new();
  let mut headers = HeaderMap::new();

  for (key, value) in &header {
    let name = HeaderName::from_lowercase(key.as_bytes()).unwrap();
    let what = value.as_str().unwrap();
    headers.insert(name, what.parse().unwrap());
  }

  let resp = client.get(&url).headers(headers).send().await?;
  let status = resp.status();
  
  if status.as_u16() != 200 {
    // return reqwest::Error::new(kind: ErrorKind::NotFound, source: status);
    return Ok(status.as_u16() as i64);
  }

  let mut stream = resp.bytes_stream();

  while let Some(item) = stream.next().await {
    // println!("Chunk: {:?}", item?);
    // println!("{}", item?.len());
    // let mut slice: &[u8] = item?.as_ref();
    task.write(item?.as_ref()).await.unwrap();
    // ii += item?.len();
    // println!("{}", ii);
  }

  // println!("body = {:?}", resp);
  Ok(0)
}

// Thread pool? I don't know  how to use that, any example is not found for threadpool(or cpupool).
async fn remote_download_handler<'a>(index: i64) {
  println!("{}", index);

  loop {
    if DOWNLOAD_QUEUE.len() > 0 {
      let x = DOWNLOAD_QUEUE.pop();
      if x.is_ok() {
        let task = x.unwrap();
        println!("{}|{}", index, task.url);
        let down = download(task.url.to_string(), task.fullpath.to_string(), task.header).await;
        if down.is_err() {
          match down {
            Err(e) => {
              // println!("Error: {}", e);
              // println!("Caused by: {}", e.source().unwrap());
            }
            Ok(i) => {
              // println!("No error");
            }
          }
          DOWNLOAD_ERROR_COUNT.fetch_add(1, Ordering::SeqCst);
          continue;
        }
      }
    }

    while DOWNLOAD_QUEUE.len() == 0 {
        // Where is semaphore for rust?
      thread::sleep(Duration::from_millis(100));

      unsafe{if DOWNLOADER_DISPOSED {return}}
    }
    
    unsafe {if  DOWNLOADER_DISPOSED {return}}
  }
}

extern crate reqwest;


fn main()  {

  
    // let url = "https://steemitimages.com/DQmYWcEumaw1ajSge5PcGpgPpXydTkTcqe1daF4Ro3sRLDi/IMG_20130103_103123.jpg";

    // // In real life we'd want an asynchronous reactor, such as the tokio_core, but for a short example the `CpuPool` should do.
    // let pool = CpuPool::new(1);
    // let https = hyper_rustls::HttpsConnector::new();
    // let client: Client<_, hyper::Body> = Client::builder().build(https);

    // // `unwrap` is used because there are different ways (and/or libraries) to handle the errors and you should pick one yourself.
    // // Also to keep this example simple.
    // let req = Request::builder().uri(url).body(Body::empty()).unwrap();
    // let fut = client.request(req);

    // // Rebinding (shadowing) the `fut` variable allows us (in smart IDEs) to more easily examine the gradual weaving of the types.
    // let fut = fut.then(move |res| {
    //     let res = res.unwrap();
    //     println!("Status: {:?}.", res.status());
    //     let body = res.into_body();
    //     // `for_each` returns a `Future` that we must embed into our chain of futures in order to execute it.
    //     body.for_each(move |chunk| {println!("Got a chunk of {} bytes.", chunk.len()); Ok(())})
    // });

    // // Handle the errors: we need error-free futures for `spawn`.
    // let fut = fut.then(move |r| -> Result<(), ()> {r.unwrap(); Ok(())});

    // // Spawning the future onto a runtime starts executing it in background.
    // // If not spawned onto a runtime the future will be executed in `wait`.
    // // 
    // // Note that we should keep the future around.
    // // To save resources most implementations would *cancel* the dropped futures.
    // let _fut = pool.spawn(fut);

    // thread::sleep (Duration::from_secs (1));  // or `_fut.wait()`.
  let mut list = Vec::new();

  let info = r#"
  {
    "id": 1234,
    "url": "https://releases.ubuntu.com/20.04/ubuntu-20.04-desktop-amd64.iso?_ga=2.61351020.1568697307.1595752688-82168734.1595752688",
    "fullpath": "ubuntu-20.04-desktop-amd64.iso",
    "header": {
      "asdf": "asdf"
    }
  }"#;
  let info2 = r#"
  {
    "id": 1234,
    "url": "https://ba.hitomi.la/webp/e/07/632dd80900c0d3e4a4d2b6469139e68363721b3775eea601ede75affd21f507e.webp",
    "fullpath": "632dd80900c0d3e4a4d2b6469139e68363721b3775eea601ede75affd21f507e.webp",
    "header": {
      "referer": "https://hitomi.la/reader/1671821.html"
    }
  }"#;

  
  let task: DownloadTask = serde_json::from_str(info).unwrap();
  let task2: DownloadTask = serde_json::from_str(info2).unwrap();

  DOWNLOAD_QUEUE.push(task).ok();
  DOWNLOAD_QUEUE.push(task2).ok();

  for x in 0..10 {
    list.push(thread::spawn(move || {
        Runtime::new()
          .expect("Failed to create Tokio runtime").
          block_on(remote_download_handler(x));
    }));
  }

  thread::sleep(Duration::from_millis(100));

  for ii in 12..100 {
    thread::sleep(Duration::from_millis(100));
  }

  for thread in list {
    thread.join().unwrap();
  }
}