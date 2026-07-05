use std::cmp::Ordering;
use std::collections::{HashMap, HashSet};
use std::fs::File;
use std::path::PathBuf;
use std::sync::{Arc, LazyLock, Mutex};

use itertools::Itertools;
use rayon::iter::{IntoParallelRefIterator, ParallelIterator};
use serde::{Deserialize, Serialize};

use crate::binding::{CachedPartialRatio, CachedRatio, SimilarityMethod};
use crate::cache::with_cache;
use crate::displant::HangulConverter;

static MESSAGES: LazyLock<Mutex<MessageStore>> =
    LazyLock::new(|| Mutex::new(MessageStore::default()));

#[derive(Default)]
struct MessageStore {
    messages: Vec<Arc<Message>>,
    by_article: HashMap<usize, Vec<Arc<Message>>>,
}

impl MessageStore {
    #[cfg(test)]
    fn from_messages(messages: Vec<Message>) -> Self {
        let mut store = Self::default();
        store.extend(messages);
        store
    }

    fn extend(&mut self, messages: Vec<Message>) {
        for message in messages {
            let message = Arc::new(message);
            self.by_article
                .entry(message.article_id)
                .or_default()
                .push(message.clone());
            self.messages.push(message);
        }
    }
}

#[derive(Deserialize, Serialize, Debug, Clone)]
pub struct Message {
    #[serde(rename = "ArticleId")]
    pub article_id: usize,

    #[serde(rename = "Page")]
    pub page: usize,

    #[serde(rename = "Message")]
    pub message: String,

    #[serde(rename = "MessageRaw", skip_serializing_if = "Option::is_none", default)]
    pub raw: Option<String>,

    #[serde(rename = "Score")]
    pub correct: f64,

    #[serde(rename = "Rectangle")]
    pub rects: [f64; 4],
}

#[derive(Serialize, Clone)]
#[cfg_attr(not(feature = "raw"), derive(Copy))]
pub struct MessageResult {
    #[serde(rename(serialize = "Id"))]
    id: usize,

    #[serde(rename(serialize = "Page"))]
    page: usize,

    #[serde(rename(serialize = "Correctness"))]
    correct: f64,

    #[serde(rename(serialize = "MatchScore"))]
    score: f64,

    #[serde(rename(serialize = "Rect"))]
    rects: [f64; 4],

    #[cfg(feature = "raw")]
    #[serde(rename(serialize = "Raw"))]
    raw: String,
}

impl From<&Message> for MessageResult {
    fn from(msg: &Message) -> Self {
        MessageResult {
            id: msg.article_id,
            page: msg.page,
            correct: msg.correct,
            rects: msg.rects,
            #[cfg(feature = "raw")]
            raw: msg.raw.clone().unwrap_or_default(),
            score: Default::default(),
        }
    }
}

pub fn load_messages(path: PathBuf) {
    let file = File::open(path).unwrap();
    let msgs: Vec<Message> = simd_json::serde::from_reader(file).unwrap();
    MESSAGES.lock().unwrap().extend(msgs);
}

pub fn search_similar(id: Option<usize>, query: &str, take: usize) -> Vec<MessageResult> {
    let converted_query = convert_query(query);
    with_cache(format!("similar-{id:?}-{converted_query}"), move || {
        search(
            candidate_messages(id),
            CachedRatio::from(&converted_query),
            |_| true,
            take,
        )
    })
}

pub fn search_similar_many(ids: &[usize], query: &str, take: usize) -> Vec<MessageResult> {
    let ids = normalize_article_ids(ids);
    if ids.is_empty() {
        return vec![];
    }
    let id_set: HashSet<_> = ids.iter().copied().collect();
    let id_key = article_ids_cache_key(&ids);
    let converted_query = convert_query(query);
    with_cache(format!("similar-many-{id_key}-{converted_query}"), move || {
        search(
            candidate_messages_many(&ids),
            CachedRatio::from(&converted_query),
            move |message| id_set.contains(&message.article_id),
            take,
        )
    })
}

pub fn search_partial_contains(id: Option<usize>, query: &str, take: usize) -> Vec<MessageResult> {
    let converted_query = convert_query(query);
    with_cache(format!("contains-{id:?}-{converted_query}"), move || {
        search(
            candidate_messages(id),
            CachedPartialRatio::from(&converted_query),
            |message| converted_query.len() <= message.message.len(),
            take,
        )
    })
}

pub fn search_partial_contains_many(
    ids: &[usize],
    query: &str,
    take: usize,
) -> Vec<MessageResult> {
    let ids = normalize_article_ids(ids);
    if ids.is_empty() {
        return vec![];
    }
    let id_set: HashSet<_> = ids.iter().copied().collect();
    let id_key = article_ids_cache_key(&ids);
    let converted_query = convert_query(query);
    with_cache(format!("contains-many-{id_key}-{converted_query}"), move || {
        search(
            candidate_messages_many(&ids),
            CachedPartialRatio::from(&converted_query),
            move |message| {
                id_set.contains(&message.article_id)
                    && converted_query.len() <= message.message.len()
            },
            take,
        )
    })
}

pub fn convert_query(query: &str) -> String {
    let mut query = HangulConverter::total_disassembly(query);
    query.retain(|c| !c.is_whitespace());
    query
}

fn normalize_article_ids(ids: &[usize]) -> Vec<usize> {
    ids.iter().copied().unique().sorted().collect()
}

fn article_ids_cache_key(ids: &[usize]) -> String {
    ids.iter().join(",")
}

fn candidate_messages(id: Option<usize>) -> Vec<Arc<Message>> {
    let store = MESSAGES.lock().unwrap();
    match id {
        Some(id) => store.by_article.get(&id).cloned().unwrap_or_default(),
        None => store.messages.clone(),
    }
}

fn candidate_messages_many(ids: &[usize]) -> Vec<Arc<Message>> {
    let store = MESSAGES.lock().unwrap();
    ids.iter()
        .filter_map(|id| store.by_article.get(id))
        .flat_map(|messages| messages.iter().cloned())
        .collect()
}

fn search(
    candidates: Vec<Arc<Message>>,
    scorer: impl SimilarityMethod,
    filter: impl Fn(&Message) -> bool + Sync + Send,
    take: usize,
) -> Vec<MessageResult> {
    let mut results: Vec<_> = candidates
        .par_iter()
        .filter(|message| filter(message.as_ref()))
        .map(|message| (message.clone(), scorer.similarity(&message.message)))
        .collect();

    results.sort_by(|(amsg, ascore), (bmsg, bscore)| {
        let ord = ascore.partial_cmp(bscore).unwrap();
        match ord {
            Ordering::Greater | Ordering::Less => ord.reverse(),
            Ordering::Equal => amsg.correct.partial_cmp(&bmsg.correct).unwrap().reverse(),
        }
    });

    results
        .into_iter()
        .take(take)
        .map(|(msg, score)| {
            let mut result: MessageResult = msg.as_ref().into();
            result.score = score;
            result
        })
        .collect()
}

pub fn search_article(id: usize) -> Vec<MessageResult> {
    candidate_messages(Some(id))
        .iter()
        .map(|msg| msg.as_ref().into())
        .collect()
}

pub fn article_lists() -> Vec<usize> {
    MESSAGES
        .lock()
        .unwrap()
        .by_article
        .keys()
        .copied()
        .sorted()
        .collect()
}

#[cfg(test)]
fn article_candidate_count(id: usize) -> usize {
    candidate_messages(Some(id)).len()
}

#[cfg(test)]
mod tests {
    use super::*;

    static TEST_LOCK: LazyLock<Mutex<()>> = LazyLock::new(|| Mutex::new(()));

    fn test_message(article_id: usize, message: &str) -> Message {
        Message {
            article_id,
            page: 1,
            message: message.to_string(),
            raw: None,
            correct: 1.0,
            rects: [0.0, 0.0, 1.0, 1.0],
        }
    }

    fn reset_messages(messages: Vec<Message>) {
        *MESSAGES.lock().unwrap() = MessageStore::from_messages(messages);
    }

    #[test]
    fn article_candidate_count_uses_article_scope() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset_messages(vec![
            test_message(10, "first"),
            test_message(10, "second"),
            test_message(20, "third"),
        ]);

        assert_eq!(article_candidate_count(10), 2);
        assert_eq!(article_candidate_count(20), 1);
        assert_eq!(article_candidate_count(30), 0);
    }

    #[test]
    fn partial_contains_many_filters_to_requested_articles() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset_messages(vec![
            test_message(10, "multiarticleunique"),
            test_message(20, "multiarticleunique"),
            test_message(30, "multiarticleunique"),
        ]);

        let results = search_partial_contains_many(&[10, 20], "multiarticleunique", 10);
        let article_ids: Vec<_> = results.iter().map(|result| result.id).sorted().collect();

        assert_eq!(article_ids, vec![10, 20]);
    }
}
