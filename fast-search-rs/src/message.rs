use std::fs::File;
use std::path::PathBuf;
use std::sync::{LazyLock, Mutex};

use serde::Deserialize;

static MESSAGES: LazyLock<Mutex<Vec<Message>>> = LazyLock::new(|| Mutex::new(vec![]));

#[derive(Deserialize, Debug, Clone)]
pub struct Message {
    #[serde(rename(deserialize = "ArticleId"))]
    article_id: usize,

    #[serde(rename(deserialize = "Page"))]
    page: f64,

    #[serde(rename(deserialize = "Message"))]
    message: String,

    #[serde(rename(deserialize = "Score"))]
    score: f64,

    #[serde(rename(deserialize = "Rectangle"))]
    rects: [f64; 4],
}

pub fn load_messages(path: PathBuf) {
    let file = File::open(path).unwrap();
    let msgs: Vec<Message> = simd_json::serde::from_reader(file).unwrap();
    MESSAGES.lock().unwrap().extend(msgs);
}
