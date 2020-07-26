// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

use std::collections::HashMap;
use std::os::raw::{c_char};
use std::ffi::{CString, CStr};
use std::thread;
use std::time::Duration;
use std::sync::{Arc, Mutex};
use std::sync::atomic::{AtomicUsize, Ordering};
// use std::sync::mpsc::channel;
// use std::rc::Rc;
use serde::{Deserialize, Serialize};
use tokio::runtime::Runtime;
use std::io;
use std::fs::File;
use serde_json::json;

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
}

async fn download(url: String, fullpath: String, header: HashMap<String, serde_json::Value>) -> Result<(), reqwest::Error> {
  // let text = reqwest::get("https://www.rust-lang.org").await?
  //       .text().await?;
    
  //   println!("body = {:?}", text);
  //   Ok(())
    let resp = reqwest::get(&url).await?.text().await?;
    // let mut out = File::create(fullpath).expect("failed to create file");
    // io::copy(&mut resp, &mut out).expect("failed to copy content");

    println!("body = {:?}", resp);
    Ok(())
}

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
  let mut list = Vec::new();
  
  let info = r#"
  {
    "id": 1234,
    "url": "zasdf",
    "fullpath": "asdf",
    "header": {
      "asdf": "asdf"
    }
  }"#;
  
  let task: DownloadTask = serde_json::from_str(info).unwrap();

  DOWNLOAD_QUEUE.push(task).ok();

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