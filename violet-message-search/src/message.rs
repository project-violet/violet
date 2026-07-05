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

type ScoredMessage = (Arc<Message>, f64);

struct TopScoredMessages {
    results: Vec<ScoredMessage>,
    scored: usize,
    take: usize,
}

impl TopScoredMessages {
    fn new(take: usize) -> Self {
        Self {
            results: Vec::with_capacity(take),
            scored: 0,
            take,
        }
    }

    fn push(&mut self, message: &Arc<Message>, score: f64) {
        self.scored += 1;
        if self.take == 0 {
            return;
        }
        if !self.is_top_result(score, message.correct) {
            return;
        }

        self.push_scored((message.clone(), score));
    }

    fn push_scored(&mut self, message: ScoredMessage) {
        if self.take == 0 {
            return;
        }
        if !self.is_top_result(message.1, message.0.correct) {
            return;
        }

        let index = self
            .results
            .binary_search_by(|existing| scored_message_order(existing, &message))
            .unwrap_or_else(|index| index);
        self.results.insert(index, message);
        if self.results.len() > self.take {
            self.results.pop();
        }
    }

    fn is_top_result(&self, score: f64, correct: f64) -> bool {
        if self.results.len() < self.take {
            return true;
        }
        let (worst_message, worst_score) = self.results.last().unwrap();
        score_correct_order(score, correct, *worst_score, worst_message.correct) == Ordering::Less
    }

    fn merge(mut self, other: Self) -> Self {
        self.scored += other.scored;
        for message in other.results {
            self.push_scored(message);
        }
        self
    }

    fn into_sorted_vec(self) -> Vec<ScoredMessage> {
        self.results
    }
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
    let top_results = candidates
        .par_iter()
        .fold(
            || TopScoredMessages::new(take),
            |mut top_results, message| {
                if filter(message.as_ref()) {
                    top_results.push(message, scorer.similarity(&message.message));
                }
                top_results
            },
        )
        .reduce(
            || TopScoredMessages::new(take),
            |left, right| left.merge(right),
        );
    let score_elapsed = score_start.elapsed();
    let scored_len = top_results.scored;

    let sort_start = Instant::now();
    let results = top_results.into_sorted_vec();
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

#[cfg(test)]
fn retain_top_results(results: &mut Vec<ScoredMessage>, take: usize) {
    if take == 0 {
        results.clear();
        return;
    }
    if results.len() > take {
        results.select_nth_unstable_by(take, scored_message_order);
        results.truncate(take);
    }
    results.sort_by(scored_message_order);
}

fn scored_message_order(
    (amsg, ascore): &ScoredMessage,
    (bmsg, bscore): &ScoredMessage,
) -> Ordering {
    score_correct_order(*ascore, amsg.correct, *bscore, bmsg.correct)
}

fn score_correct_order(
    ascore: f64,
    acorrect: f64,
    bscore: f64,
    bcorrect: f64,
) -> Ordering {
    let ord = ascore.partial_cmp(&bscore).unwrap();
    match ord {
        Ordering::Greater | Ordering::Less => ord.reverse(),
        Ordering::Equal => acorrect.partial_cmp(&bcorrect).unwrap().reverse(),
    }
}

#[cfg(test)]
fn collect_top_results(results: Vec<ScoredMessage>, take: usize) -> Vec<ScoredMessage> {
    let mut top_results = TopScoredMessages::new(take);
    for result in results {
        top_results.push_scored(result);
    }
    top_results.into_sorted_vec()
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

    fn test_message_with_correct(article_id: usize, correct: f64) -> Arc<Message> {
        Arc::new(Message {
            article_id,
            page: 1,
            message: "message".to_string(),
            raw: None,
            correct,
            rects: [0.0, 0.0, 1.0, 1.0],
        })
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

    #[test]
    fn retain_top_results_limits_and_preserves_sort_order() {
        let mut results = vec![
            (test_message_with_correct(1, 0.1), 10.0),
            (test_message_with_correct(2, 0.2), 20.0),
            (test_message_with_correct(3, 0.9), 20.0),
            (test_message_with_correct(4, 0.9), 5.0),
        ];

        retain_top_results(&mut results, 2);

        let article_ids: Vec<_> = results.iter().map(|(message, _)| message.article_id).collect();
        assert_eq!(article_ids, vec![3, 2]);
    }

    #[test]
    fn collect_top_results_matches_full_top_k_order() {
        let results = vec![
            (test_message_with_correct(1, 0.1), 10.0),
            (test_message_with_correct(2, 0.2), 20.0),
            (test_message_with_correct(3, 0.9), 20.0),
            (test_message_with_correct(4, 0.9), 5.0),
            (test_message_with_correct(5, 0.8), 30.0),
        ];
        let mut full_results = results.clone();
        retain_top_results(&mut full_results, 3);

        let top_results = collect_top_results(results, 3);

        let full_article_ids: Vec<_> = full_results
            .iter()
            .map(|(message, _)| message.article_id)
            .collect();
        let top_article_ids: Vec<_> = top_results
            .iter()
            .map(|(message, _)| message.article_id)
            .collect();

        assert_eq!(top_article_ids, full_article_ids);
    }

    #[test]
    fn merged_top_results_match_full_top_k_order() {
        let results = vec![
            (test_message_with_correct(1, 0.1), 10.0),
            (test_message_with_correct(2, 0.2), 20.0),
            (test_message_with_correct(3, 0.9), 20.0),
            (test_message_with_correct(4, 0.9), 5.0),
            (test_message_with_correct(5, 0.8), 30.0),
            (test_message_with_correct(6, 0.7), 25.0),
        ];
        let mut full_results = results.clone();
        retain_top_results(&mut full_results, 3);

        let mut left = TopScoredMessages::new(3);
        let mut right = TopScoredMessages::new(3);
        for (message, score) in results.iter().take(3) {
            left.push(message, *score);
        }
        for (message, score) in results.iter().skip(3) {
            right.push(message, *score);
        }
        let top_results = left.merge(right).into_sorted_vec();

        let full_article_ids: Vec<_> = full_results
            .iter()
            .map(|(message, _)| message.article_id)
            .collect();
        let top_article_ids: Vec<_> = top_results
            .iter()
            .map(|(message, _)| message.article_id)
            .collect();

        assert_eq!(top_article_ids, full_article_ids);
    }
}
