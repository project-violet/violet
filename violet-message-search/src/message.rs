use std::cmp::Ordering;
use std::collections::{HashMap, HashSet};
use std::env;
use std::fs::File;
use std::path::PathBuf;
use std::sync::{Arc, LazyLock, Mutex};
use std::time::{Duration, Instant};

use itertools::Itertools;
use rayon::iter::{IntoParallelRefIterator, ParallelIterator};
use serde::{Deserialize, Serialize};

use crate::binding::{CachedPartialRatio, CachedRatio, SimilarityMethod};
use crate::cache::{with_cache_status, CacheStatus};
use crate::displant::HangulConverter;

static MESSAGES: LazyLock<Mutex<MessageStore>> =
    LazyLock::new(|| Mutex::new(MessageStore::default()));

#[derive(Default)]
struct MessageStore {
    messages: Vec<Arc<Message>>,
    by_article: HashMap<usize, Vec<Arc<Message>>>,
}

#[derive(Default)]
struct SearchStats {
    candidates: usize,
    scored: usize,
    score_elapsed: Duration,
    sort_elapsed: Duration,
    take_elapsed: Duration,
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
    search_with_profile(
        "similar",
        format!("similar-{id:?}-{converted_query}"),
        query,
        &converted_query,
        format!("id={id:?}"),
        move || candidate_messages(id),
        CachedRatio::from(&converted_query),
        |_| true,
        take,
    )
}

pub fn search_similar_many(ids: &[usize], query: &str, take: usize) -> Vec<MessageResult> {
    let ids = normalize_article_ids(ids);
    if ids.is_empty() {
        return vec![];
    }
    let id_set: HashSet<_> = ids.iter().copied().collect();
    let id_key = article_ids_cache_key(&ids);
    let converted_query = convert_query(query);
    let scope = format!("ids={}", ids.len());
    search_with_profile(
        "similar-many",
        format!("similar-many-{id_key}-{converted_query}"),
        query,
        &converted_query,
        scope,
        move || candidate_messages_many(&ids),
        CachedRatio::from(&converted_query),
        move |message| id_set.contains(&message.article_id),
        take,
    )
}

pub fn search_partial_contains(id: Option<usize>, query: &str, take: usize) -> Vec<MessageResult> {
    let converted_query = convert_query(query);
    let converted_query_len = converted_query.len();
    search_with_profile(
        "contains",
        format!("contains-{id:?}-{converted_query}"),
        query,
        &converted_query,
        format!("id={id:?}"),
        move || candidate_messages(id),
        CachedPartialRatio::from(&converted_query),
        move |message| converted_query_len <= message.message.len(),
        take,
    )
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
    let converted_query_len = converted_query.len();
    let scope = format!("ids={}", ids.len());
    search_with_profile(
        "contains-many",
        format!("contains-many-{id_key}-{converted_query}"),
        query,
        &converted_query,
        scope,
        move || candidate_messages_many(&ids),
        CachedPartialRatio::from(&converted_query),
        move |message| {
            id_set.contains(&message.article_id) && converted_query_len <= message.message.len()
        },
        take,
    )
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

fn search_with_profile(
    label: &'static str,
    cache_key: String,
    raw_query: &str,
    converted_query: &str,
    scope: String,
    candidates: impl FnOnce() -> Vec<Arc<Message>>,
    scorer: impl SimilarityMethod,
    filter: impl Fn(&Message) -> bool + Sync + Send,
    take: usize,
) -> Vec<MessageResult> {
    let profile_enabled = search_profile_enabled();
    let raw_query = raw_query.to_string();
    let converted_query = converted_query.to_string();
    let total_start = Instant::now();
    let miss_scope = scope.clone();
    let miss_raw_query = raw_query.clone();
    let miss_converted_query = converted_query.clone();

    let (results, cache_status) = with_cache_status(cache_key, move || {
        let candidate_start = Instant::now();
        let candidates = candidates();
        let candidate_elapsed = candidate_start.elapsed();
        let (results, stats) = search(candidates, scorer, filter, take);
        if profile_enabled {
            log_search_profile(
                label,
                "miss",
                &miss_scope,
                &miss_raw_query,
                &miss_converted_query,
                take,
                candidate_elapsed,
                Some(&stats),
                total_start.elapsed(),
            );
        }
        results
    });

    if profile_enabled && cache_status == CacheStatus::Hit {
        log_search_profile(
            label,
            "hit",
            &scope,
            &raw_query,
            &converted_query,
            take,
            Duration::default(),
            None,
            total_start.elapsed(),
        );
    }

    results
}

fn search(
    candidates: Vec<Arc<Message>>,
    scorer: impl SimilarityMethod,
    filter: impl Fn(&Message) -> bool + Sync + Send,
    take: usize,
) -> (Vec<MessageResult>, SearchStats) {
    let candidates_len = candidates.len();
    let score_start = Instant::now();
    let mut results: Vec<_> = candidates
        .par_iter()
        .filter(|message| filter(message.as_ref()))
        .map(|message| (message.clone(), scorer.similarity(&message.message)))
        .collect();
    let score_elapsed = score_start.elapsed();
    let scored_len = results.len();

    let sort_start = Instant::now();
    results.sort_by(|(amsg, ascore), (bmsg, bscore)| {
        let ord = ascore.partial_cmp(bscore).unwrap();
        match ord {
            Ordering::Greater | Ordering::Less => ord.reverse(),
            Ordering::Equal => amsg.correct.partial_cmp(&bmsg.correct).unwrap().reverse(),
        }
    });
    let sort_elapsed = sort_start.elapsed();

    let take_start = Instant::now();
    let results = results
        .into_iter()
        .take(take)
        .map(|(msg, score)| {
            let mut result: MessageResult = msg.as_ref().into();
            result.score = score;
            result
        })
        .collect();
    let take_elapsed = take_start.elapsed();

    (
        results,
        SearchStats {
            candidates: candidates_len,
            scored: scored_len,
            score_elapsed,
            sort_elapsed,
            take_elapsed,
        },
    )
}

fn search_profile_enabled() -> bool {
    env::var("FSCM_PROFILE")
        .map(|value| value != "0" && !value.eq_ignore_ascii_case("false"))
        .unwrap_or(false)
}

fn log_search_profile(
    label: &str,
    cache: &str,
    scope: &str,
    raw_query: &str,
    converted_query: &str,
    take: usize,
    candidate_elapsed: Duration,
    stats: Option<&SearchStats>,
    total_elapsed: Duration,
) {
    let converted_len = converted_query.len();
    match stats {
        Some(stats) => println!(
            "[fscm-profile] op={label} cache={cache} {scope} query={raw_query:?} converted_len={converted_len} take={take} candidates={} scored={} candidate_ms={:.3} score_ms={:.3} sort_ms={:.3} take_ms={:.3} total_ms={:.3}",
            stats.candidates,
            stats.scored,
            millis(candidate_elapsed),
            millis(stats.score_elapsed),
            millis(stats.sort_elapsed),
            millis(stats.take_elapsed),
            millis(total_elapsed),
        ),
        None => println!(
            "[fscm-profile] op={label} cache={cache} {scope} query={raw_query:?} converted_len={converted_len} take={take} total_ms={:.3}",
            millis(total_elapsed),
        ),
    }
}

fn millis(duration: Duration) -> f64 {
    duration.as_secs_f64() * 1000.0
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
