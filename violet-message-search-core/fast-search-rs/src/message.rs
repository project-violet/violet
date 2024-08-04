use std::fs::File;
use std::path::PathBuf;
use std::sync::{Arc, LazyLock, Mutex};

use rayon::iter::{IntoParallelRefIterator, ParallelIterator};
use serde::{Deserialize, Serialize};

use crate::binding::{CachedPartialRatio, CachedRatio, SimilarityMethod};
use crate::displant::HangulConverter;

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

#[derive(Serialize)]
pub struct MessageResult {
    id: usize,
    page: f64,
    score: f64,
    rects: [f64; 4],
}

pub fn load_messages(path: PathBuf) {
    let file = File::open(path).unwrap();
    let msgs: Vec<Message> = simd_json::serde::from_reader(file).unwrap();
    MESSAGES
        .lock()
        .unwrap()
        .extend(msgs.into_iter().map(Arc::new));
}

pub fn search_similar(query: &str, take: usize) -> Vec<MessageResult> {
    let converted_query = convert_query(query);
    search(CachedRatio::from(&converted_query), take)
}

pub fn search_partial_contains(query: &str, take: usize) -> Vec<MessageResult> {
    let converted_query = convert_query(query);
    search(CachedPartialRatio::from(&converted_query), take)
}

fn convert_query(query: &str) -> String {
    let mut query = HangulConverter::total_disassembly(query);
    query.retain(|c| !c.is_whitespace());
    query
}

fn search(scorer: impl SimilarityMethod, take: usize) -> Vec<MessageResult> {
    let mut results: Vec<_> = MESSAGES
        .lock()
        .unwrap()
        .par_iter()
        .map(|message| (message.clone(), scorer.similarity(&message.message)))
        .collect();

    results.sort_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap().reverse());

    results
        .into_iter()
        .take(take)
        .map(|(msg, score)| MessageResult {
            id: msg.article_id,
            page: msg.page,
            score,
            rects: msg.rects,
        })
        .collect()
}
