use std::os::raw::{c_char};
use std::ffi::{CString, CStr};

#[no_mangle]
pub extern fn rust_greeting(to: *const c_char) -> *mut c_char {
  let c_str = unsafe { CStr::from_ptr(to) };
  let recipient = match c_str.to_str() {
    Err(_) => "there",
    Ok(string) => string,
  };
  CString::new("Hello ".to_owned() + recipient).unwrap().into_raw()
}

extern crate reqwest;

use futures::executor::block_on;
use std::io;
use std::fs::File;
use std::borrow::Cow;
use tokio::runtime::Runtime;

fn basename<'a>(path: &'a String, sep: char) -> Cow<'a, str> {
    let mut pieces = path.rsplit(sep);
    match pieces.next() {
        Some(p) => p.into(),
        None => path.into(),
    }
}

async fn download(url: String) -> Result<(), reqwest::Error> {
  // let text = reqwest::get("https://www.rust-lang.org").await?
  //       .text().await?;
    
  //   println!("body = {:?}", text);
  //   Ok(())
    let resp = reqwest::get(&url).await?.text().await?;
    // let mut out = File::create(basename(&url, '/').to_string()).expect("failed to create file");
    // io::copy(&mut resp, &mut out).expect("failed to copy content");

    println!("body = {:?}", resp);
    Ok(())
}

fn main()  {
  Runtime::new()
        .expect("Failed to create Tokio runtime").
    block_on(download("http://releases.ubuntu.com/bionic/ubuntu-18.04.1-desktop-amd64.iso".to_string()));
}