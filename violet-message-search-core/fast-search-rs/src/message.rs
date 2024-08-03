use std::fs::File;
use std::path::PathBuf;
use std::sync::{Arc, LazyLock, Mutex};

use rayon::iter::{IntoParallelRefIterator, ParallelIterator};
use serde::Deserialize;

use crate::binding::CachedRatio;

static MESSAGES: LazyLock<Mutex<Vec<Arc<Message>>>> = LazyLock::new(|| Mutex::new(vec![]));

#[derive(Deserialize, Debug, Clone)]
pub struct Message {
    #[serde(rename(deserialize = "ArticleId"))]
    pub article_id: usize,

    #[serde(rename(deserialize = "Page"))]
    pub page: f64,

    #[serde(rename(deserialize = "Message"))]
    pub message: String,

    // #[serde(rename(deserialize = "MessageRaw"))]
    // pub raw: String,

    // #[serde(rename(deserialize = "Score"))]
    // pub score: f64,
    #[serde(rename(deserialize = "Rectangle"))]
    pub rects: [f64; 4],
}

pub fn load_messages(path: PathBuf) {
    let file = File::open(path).unwrap();
    let msgs: Vec<Message> = simd_json::serde::from_reader(file).unwrap();
    MESSAGES
        .lock()
        .unwrap()
        .extend(msgs.into_iter().map(Arc::new));
}

pub fn search_similar(query: &str, take: usize) -> Vec<(Arc<Message>, f64)> {
    let scorer = CachedRatio::from(query);

    let mut results: Vec<_> = MESSAGES
        .lock()
        .unwrap()
        .par_iter()
        .map(|message| (message.clone(), scorer.similarity(&message.message)))
        .collect();

    results.sort_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap().reverse());

    results.into_iter().take(take).collect()
}
