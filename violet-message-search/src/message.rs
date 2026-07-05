use std::cmp::Ordering;
use std::collections::{BinaryHeap, HashMap, HashSet};
use std::env;
use std::fs::File;
use std::io::{self, BufReader, Read, Write};
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering as AtomicOrdering};
use std::sync::{LazyLock, RwLock};
use std::time::{Duration, Instant};

use itertools::Itertools;
use rayon::iter::{IntoParallelIterator, IntoParallelRefIterator, ParallelIterator};
use serde::{Deserialize, Serialize};

use crate::binding::{CachedPartialRatio, CachedRatio, SimilarityMethod};
use crate::cache::{with_cache_status, CacheStatus};
use crate::displant::HangulConverter;

static MESSAGES: LazyLock<RwLock<MessageStore>> =
    LazyLock::new(|| RwLock::new(MessageStore::default()));

#[derive(Default)]
struct MessageStore {
    messages: Vec<MessageMeta>,
    message_bytes: Vec<u8>,
    by_article: HashMap<u32, Vec<MessageIndex>>,
}

#[derive(Default)]
struct SearchStats {
    candidates: usize,
    scored: usize,
    exact_scored: usize,
    fuzzy_scored: usize,
    score_elapsed: Duration,
    sort_elapsed: Duration,
    take_elapsed: Duration,
}

type MessageIndex = u32;

const FLAT_MAGIC: &[u8; 8] = b"FSCMMSG1";
const FLAT_VERSION: u32 = 1;
const FLAT_FLAG_RAW: u32 = 1;
const FLAT_RECORD_LEN: usize = 52;

#[derive(Clone, Copy)]
struct TextRange {
    offset: u64,
    len: u32,
}

#[derive(Clone, Copy)]
struct MessageMeta {
    article_id: u32,
    page: u32,
    message: TextRange,

    #[cfg(feature = "raw")]
    raw: Option<TextRange>,

    correct: f32,
    rects: [f32; 4],
}

struct StoredMessage<'a> {
    article_id: u32,
    page: u32,
    message: &'a str,

    #[cfg(feature = "raw")]
    raw: Option<&'a str>,

    correct: f32,
    rects: [f32; 4],
}

#[derive(Clone, Copy)]
struct FlatRecord {
    article_id: u32,
    page: u32,
    message_offset: u64,
    message_len: u32,
    raw_offset: u64,
    raw_len: u32,
    correct: f32,
    rects: [f32; 4],
}

#[allow(dead_code)]
#[derive(Default)]
pub struct FlatMessageWriter {
    messages: Vec<MessageMeta>,
    message_bytes: Vec<u8>,
}

impl FlatRecord {
    #[allow(dead_code)]
    fn from_meta(meta: MessageMeta) -> Self {
        Self {
            article_id: meta.article_id,
            page: meta.page,
            message_offset: meta.message.offset,
            message_len: meta.message.len,
            #[cfg(feature = "raw")]
            raw_offset: meta.raw.map_or(0, |raw| raw.offset),
            #[cfg(not(feature = "raw"))]
            raw_offset: 0,
            #[cfg(feature = "raw")]
            raw_len: meta.raw.map_or(0, |raw| raw.len),
            #[cfg(not(feature = "raw"))]
            raw_len: 0,
            correct: meta.correct,
            rects: meta.rects,
        }
    }

    fn read_from<R: Read>(reader: &mut R) -> io::Result<Self> {
        let mut bytes = [0; FLAT_RECORD_LEN];
        reader.read_exact(&mut bytes)?;
        let mut cursor = 0;
        let article_id = read_u32_from(&bytes, &mut cursor);
        let page = read_u32_from(&bytes, &mut cursor);
        let message_offset = read_u64_from(&bytes, &mut cursor);
        let message_len = read_u32_from(&bytes, &mut cursor);
        let raw_offset = read_u64_from(&bytes, &mut cursor);
        let raw_len = read_u32_from(&bytes, &mut cursor);
        let correct = f32::from_bits(read_u32_from(&bytes, &mut cursor));
        let rects = [
            f32::from_bits(read_u32_from(&bytes, &mut cursor)),
            f32::from_bits(read_u32_from(&bytes, &mut cursor)),
            f32::from_bits(read_u32_from(&bytes, &mut cursor)),
            f32::from_bits(read_u32_from(&bytes, &mut cursor)),
        ];
        Ok(Self {
            article_id,
            page,
            message_offset,
            message_len,
            raw_offset,
            raw_len,
            correct,
            rects,
        })
    }

    #[allow(dead_code)]
    fn write_to<W: Write>(&self, writer: &mut W) -> io::Result<()> {
        write_u32(writer, self.article_id)?;
        write_u32(writer, self.page)?;
        write_u64(writer, self.message_offset)?;
        write_u32(writer, self.message_len)?;
        write_u64(writer, self.raw_offset)?;
        write_u32(writer, self.raw_len)?;
        write_u32(writer, self.correct.to_bits())?;
        for rect in self.rects {
            write_u32(writer, rect.to_bits())?;
        }
        Ok(())
    }

    fn validate(&self, bytes_len: u64) -> io::Result<()> {
        validate_range(self.message_offset, self.message_len, bytes_len)?;
        if self.raw_len > 0 {
            validate_range(self.raw_offset, self.raw_len, bytes_len)?;
        }
        Ok(())
    }
}

#[allow(dead_code)]
impl FlatMessageWriter {
    pub fn push(&mut self, message: &Message) {
        let message_range = self.push_text(&message.message);
        #[cfg(feature = "raw")]
        let raw_range = message.raw.as_deref().map(|raw| self.push_text(raw));
        self.messages.push(MessageMeta {
            article_id: message.article_id,
            page: message.page,
            message: message_range,
            #[cfg(feature = "raw")]
            raw: raw_range,
            correct: message.correct,
            rects: message.rects,
        });
    }

    pub fn write_to<W: Write>(&self, writer: &mut W) -> io::Result<()> {
        writer.write_all(FLAT_MAGIC)?;
        write_u32(writer, FLAT_VERSION)?;
        write_u32(writer, self.flags())?;
        write_u64(writer, self.messages.len() as u64)?;
        write_u64(writer, self.message_bytes.len() as u64)?;
        for meta in &self.messages {
            FlatRecord::from_meta(*meta).write_to(writer)?;
        }
        writer.write_all(&self.message_bytes)?;
        Ok(())
    }

    pub fn append(&mut self, other: Self) {
        let byte_base = u64::try_from(self.message_bytes.len()).expect("message arena too large");
        self.message_bytes.extend_from_slice(&other.message_bytes);
        self.messages.reserve(other.messages.len());
        for mut message in other.messages {
            message.message.offset += byte_base;
            #[cfg(feature = "raw")]
            if let Some(raw) = &mut message.raw {
                raw.offset += byte_base;
            }
            self.messages.push(message);
        }
    }

    fn flags(&self) -> u32 {
        #[cfg(feature = "raw")]
        {
            if self.messages.iter().any(|message| message.raw.is_some()) {
                return FLAT_FLAG_RAW;
            }
        }
        0
    }

    fn push_text(&mut self, text: &str) -> TextRange {
        let offset = u64::try_from(self.message_bytes.len()).expect("message arena too large");
        let len = u32::try_from(text.len()).expect("message text too large");
        self.message_bytes.extend_from_slice(text.as_bytes());
        TextRange { offset, len }
    }
}

fn read_u32<R: Read>(reader: &mut R) -> io::Result<u32> {
    let mut bytes = [0; 4];
    reader.read_exact(&mut bytes)?;
    Ok(u32::from_le_bytes(bytes))
}

fn read_u64<R: Read>(reader: &mut R) -> io::Result<u64> {
    let mut bytes = [0; 8];
    reader.read_exact(&mut bytes)?;
    Ok(u64::from_le_bytes(bytes))
}

fn read_u32_from(bytes: &[u8], cursor: &mut usize) -> u32 {
    let value = u32::from_le_bytes(bytes[*cursor..*cursor + 4].try_into().unwrap());
    *cursor += 4;
    value
}

fn read_u64_from(bytes: &[u8], cursor: &mut usize) -> u64 {
    let value = u64::from_le_bytes(bytes[*cursor..*cursor + 8].try_into().unwrap());
    *cursor += 8;
    value
}

#[allow(dead_code)]
fn write_u32<W: Write>(writer: &mut W, value: u32) -> io::Result<()> {
    writer.write_all(&value.to_le_bytes())
}

#[allow(dead_code)]
fn write_u64<W: Write>(writer: &mut W, value: u64) -> io::Result<()> {
    writer.write_all(&value.to_le_bytes())
}

fn validate_range(offset: u64, len: u32, bytes_len: u64) -> io::Result<()> {
    let end = offset
        .checked_add(u64::from(len))
        .ok_or_else(|| invalid_data("flat message text range overflow"))?;
    if end > bytes_len {
        return Err(invalid_data("flat message text range exceeds byte block"));
    }
    Ok(())
}

fn invalid_data(message: &'static str) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, message)
}

#[derive(Clone, Copy)]
struct ScoredMessage {
    index: usize,
    score: f64,
    correct: f32,
}

struct TopScoredMessage(ScoredMessage);

#[derive(Default)]
struct GlobalScoreCutoff {
    score_bits: AtomicU64,
}

impl GlobalScoreCutoff {
    fn get(&self) -> f64 {
        f64::from_bits(self.score_bits.load(AtomicOrdering::Relaxed))
    }

    fn publish(&self, score: f64) {
        if !score.is_finite() || score <= 0.0 {
            return;
        }

        let mut current = self.score_bits.load(AtomicOrdering::Relaxed);
        while score > f64::from_bits(current) {
            match self.score_bits.compare_exchange_weak(
                current,
                score.to_bits(),
                AtomicOrdering::Relaxed,
                AtomicOrdering::Relaxed,
            ) {
                Ok(_) => return,
                Err(next) => current = next,
            }
        }
    }
}

impl PartialEq for TopScoredMessage {
    fn eq(&self, other: &Self) -> bool {
        self.cmp(other) == Ordering::Equal
    }
}

impl Eq for TopScoredMessage {}

impl PartialOrd for TopScoredMessage {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for TopScoredMessage {
    fn cmp(&self, other: &Self) -> Ordering {
        scored_message_order(&self.0, &other.0)
    }
}

struct TopScoredMessages {
    heap: BinaryHeap<TopScoredMessage>,
    scored: usize,
    exact_scored: usize,
    fuzzy_scored: usize,
    take: usize,
}

impl TopScoredMessages {
    fn new(take: usize) -> Self {
        Self {
            heap: BinaryHeap::with_capacity(take),
            scored: 0,
            exact_scored: 0,
            fuzzy_scored: 0,
            take,
        }
    }

    fn push_exact(&mut self, index: usize, correct: f32, score: f64) {
        self.scored += 1;
        self.exact_scored += 1;
        self.push_top(index, correct, score);
    }

    fn push_fuzzy(&mut self, index: usize, correct: f32, score: f64) {
        self.scored += 1;
        self.fuzzy_scored += 1;
        self.push_top(index, correct, score);
    }

    fn push_top(&mut self, index: usize, correct: f32, score: f64) {
        if self.take == 0 {
            return;
        }

        let message = ScoredMessage {
            index,
            score,
            correct,
        };

        if self.heap.len() < self.take {
            self.heap.push(TopScoredMessage(message));
            return;
        }

        if let Some(worst) = self.heap.peek() {
            let order = scored_message_order(&message, &worst.0);
            if order == Ordering::Less {
                *self.heap.peek_mut().unwrap() = TopScoredMessage(message);
            }
        }
    }

    fn push_scored(&mut self, message: ScoredMessage) {
        if self.take == 0 {
            return;
        }

        if self.heap.len() < self.take {
            self.heap.push(TopScoredMessage(message));
            return;
        }

        if let Some(worst) = self.heap.peek() {
            if scored_message_order(&message, &worst.0) == Ordering::Less {
                *self.heap.peek_mut().unwrap() = TopScoredMessage(message);
            }
        }
    }

    fn score_cutoff(&self) -> f64 {
        if self.heap.len() < self.take {
            return 0.0;
        }
        // This cutoff is local to one Rayon worker. It is still safe: anything
        // below this worker's current worst result cannot enter that worker's
        // top-k, and therefore cannot enter the final merged top-k.
        self.heap
            .peek()
            .map(|message| message.0.score)
            .unwrap_or(0.0)
    }

    fn score_cutoff_with_global(&self, global_cutoff: &GlobalScoreCutoff) -> f64 {
        self.score_cutoff().max(global_cutoff.get())
    }

    fn publish_score_cutoff(&self, global_cutoff: &GlobalScoreCutoff) {
        global_cutoff.publish(self.score_cutoff());
    }

    fn len(&self) -> usize {
        self.heap.len()
    }

    fn merge(mut self, other: Self) -> Self {
        self.scored += other.scored;
        self.exact_scored += other.exact_scored;
        self.fuzzy_scored += other.fuzzy_scored;
        for message in other.heap {
            self.push_scored(message.0);
        }
        self
    }

    fn into_sorted_vec(self) -> Vec<ScoredMessage> {
        let mut results: Vec<_> = self.heap.into_iter().map(|message| message.0).collect();
        results.sort_by(scored_message_order);
        results
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
        self.messages.reserve(messages.len());
        self.message_bytes
            .reserve(messages.iter().map(Message::text_len).sum());
        for message in messages {
            let index = MessageIndex::try_from(self.messages.len()).expect("too many messages");
            self.by_article
                .entry(message.article_id)
                .or_default()
                .push(index);
            let message_range = self.push_text(&message.message);
            #[cfg(feature = "raw")]
            let raw_range = message.raw.as_deref().map(|raw| self.push_text(raw));
            self.messages.push(MessageMeta {
                article_id: message.article_id,
                page: message.page,
                message: message_range,
                #[cfg(feature = "raw")]
                raw: raw_range,
                correct: message.correct,
                rects: message.rects,
            });
        }
    }

    fn extend_from_flat_reader<R: Read>(&mut self, reader: R) -> io::Result<()> {
        let mut reader = BufReader::with_capacity(1024 * 1024, reader);
        let mut magic = [0; 8];
        reader.read_exact(&mut magic)?;
        if &magic != FLAT_MAGIC {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "invalid fast-search flat message magic",
            ));
        }

        let version = read_u32(&mut reader)?;
        if version != FLAT_VERSION {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                format!("unsupported fast-search flat message version {version}"),
            ));
        }

        let flags = read_u32(&mut reader)?;
        if flags & !FLAT_FLAG_RAW != 0 {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                format!("unsupported fast-search flat message flags {flags}"),
            ));
        }

        let message_count = read_u64(&mut reader)?;
        let message_bytes_len = read_u64(&mut reader)?;
        let message_count =
            usize::try_from(message_count).map_err(|_| invalid_data("too many messages"))?;
        let message_bytes_len = usize::try_from(message_bytes_len)
            .map_err(|_| invalid_data("message bytes too large"))?;

        let byte_base = u64::try_from(self.message_bytes.len())
            .map_err(|_| invalid_data("message arena too large"))?;
        self.messages.reserve(message_count);
        self.message_bytes.reserve(message_bytes_len);

        for _ in 0..message_count {
            let record = FlatRecord::read_from(&mut reader)?;
            record.validate(message_bytes_len as u64)?;
            let index = MessageIndex::try_from(self.messages.len()).map_err(|_| {
                io::Error::new(io::ErrorKind::InvalidData, "too many message indexes")
            })?;
            self.by_article
                .entry(record.article_id)
                .or_default()
                .push(index);
            self.messages.push(MessageMeta {
                article_id: record.article_id,
                page: record.page,
                message: TextRange {
                    offset: byte_base + record.message_offset,
                    len: record.message_len,
                },
                #[cfg(feature = "raw")]
                raw: (record.raw_len > 0).then_some(TextRange {
                    offset: byte_base + record.raw_offset,
                    len: record.raw_len,
                }),
                correct: record.correct,
                rects: record.rects,
            });
        }

        let start = self.message_bytes.len();
        self.message_bytes.resize(start + message_bytes_len, 0);
        reader.read_exact(&mut self.message_bytes[start..])?;
        Ok(())
    }

    fn push_text(&mut self, text: &str) -> TextRange {
        let offset = u64::try_from(self.message_bytes.len()).expect("message arena too large");
        let len = u32::try_from(text.len()).expect("message text too large");
        self.message_bytes.extend_from_slice(text.as_bytes());
        TextRange { offset, len }
    }

    fn message_at(&self, index: usize) -> StoredMessage<'_> {
        let meta = self.messages[index];
        StoredMessage {
            article_id: meta.article_id,
            page: meta.page,
            message: self.text(meta.message),
            #[cfg(feature = "raw")]
            raw: meta.raw.map(|raw| self.text(raw)),
            correct: meta.correct,
            rects: meta.rects,
        }
    }

    fn text(&self, range: TextRange) -> &str {
        let offset = usize::try_from(range.offset).expect("message offset too large");
        let len = usize::try_from(range.len).expect("message length too large");
        let bytes = &self.message_bytes[offset..offset + len];
        // Text ranges are copied from Rust strings during load, so they remain
        // valid UTF-8 while avoiding validation on every scanned candidate.
        unsafe { std::str::from_utf8_unchecked(bytes) }
    }
}

#[derive(Deserialize, Serialize, Debug, Clone)]
pub struct Message {
    #[serde(rename = "ArticleId")]
    pub article_id: u32,

    #[serde(rename = "Page")]
    pub page: u32,

    #[serde(rename = "Message")]
    pub message: String,

    #[cfg(feature = "raw")]
    #[serde(
        rename = "MessageRaw",
        skip_serializing_if = "Option::is_none",
        default
    )]
    pub raw: Option<String>,

    #[serde(rename = "Score")]
    pub correct: f32,

    #[serde(rename = "Rectangle")]
    pub rects: [f32; 4],
}

impl Message {
    fn text_len(&self) -> usize {
        let len = self.message.len();
        #[cfg(feature = "raw")]
        {
            len + self.raw.as_ref().map_or(0, String::len)
        }
        #[cfg(not(feature = "raw"))]
        {
            len
        }
    }
}

#[derive(Serialize, Clone)]
#[cfg_attr(not(feature = "raw"), derive(Copy))]
pub struct MessageResult {
    #[serde(rename(serialize = "Id"))]
    id: u32,

    #[serde(rename(serialize = "Page"))]
    page: u32,

    #[serde(rename(serialize = "Correctness"))]
    correct: f32,

    #[serde(rename(serialize = "MatchScore"))]
    score: f64,

    #[serde(rename(serialize = "Rect"))]
    rects: [f32; 4],

    #[cfg(feature = "raw")]
    #[serde(rename(serialize = "Raw"))]
    raw: String,
}

impl From<&StoredMessage<'_>> for MessageResult {
    fn from(msg: &StoredMessage<'_>) -> Self {
        MessageResult {
            id: msg.article_id,
            page: msg.page,
            correct: msg.correct,
            rects: msg.rects,
            #[cfg(feature = "raw")]
            raw: msg.raw.unwrap_or_default().to_string(),
            score: Default::default(),
        }
    }
}

pub fn load_messages(path: PathBuf) {
    let file = File::open(&path).unwrap();
    if path
        .extension()
        .is_some_and(|extension| extension == "fscm")
    {
        MESSAGES
            .write()
            .unwrap()
            .extend_from_flat_reader(file)
            .unwrap();
    } else {
        let msgs: Vec<Message> = simd_json::serde::from_reader(file).unwrap();
        MESSAGES.write().unwrap().extend(msgs);
    }
}

pub fn search_similar(id: Option<u32>, query: &str, take: usize) -> Vec<MessageResult> {
    let converted_query = convert_query(query);
    match id {
        Some(id) => search_with_profile(
            "similar",
            search_cache_key("similar", &format!("{id:?}"), &converted_query, take),
            query,
            &converted_query,
            format!("id={id:?}"),
            move |store| candidate_indices(id, store),
            CachedRatio::from(&converted_query),
            |_| true,
            take,
        ),
        None => search_all_with_profile(
            "similar",
            search_cache_key("similar", &format!("{id:?}"), &converted_query, take),
            query,
            &converted_query,
            format!("id={id:?}"),
            CachedRatio::from(&converted_query),
            |_| true,
            take,
        ),
    }
}

pub fn search_similar_many(ids: &[u32], query: &str, take: usize) -> Vec<MessageResult> {
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
        search_cache_key("similar-many", &id_key, &converted_query, take),
        query,
        &converted_query,
        scope,
        move |store| candidate_indices_many(&ids, store),
        CachedRatio::from(&converted_query),
        move |message| id_set.contains(&message.article_id),
        take,
    )
}

pub fn search_partial_contains(id: Option<u32>, query: &str, take: usize) -> Vec<MessageResult> {
    let converted_query = convert_query(query);
    let converted_query_len = converted_query.len();
    match id {
        Some(id) => search_with_profile(
            "contains",
            search_cache_key("contains", &format!("{id:?}"), &converted_query, take),
            query,
            &converted_query,
            format!("id={id:?}"),
            move |store| candidate_indices(id, store),
            CachedPartialRatio::from(&converted_query),
            move |message| converted_query_len <= message.message.len(),
            take,
        ),
        None => search_all_with_profile(
            "contains",
            search_cache_key("contains", &format!("{id:?}"), &converted_query, take),
            query,
            &converted_query,
            format!("id={id:?}"),
            CachedPartialRatio::from(&converted_query),
            move |message| converted_query_len <= message.message.len(),
            take,
        ),
    }
}

pub fn search_partial_contains_many(ids: &[u32], query: &str, take: usize) -> Vec<MessageResult> {
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
        search_cache_key("contains-many", &id_key, &converted_query, take),
        query,
        &converted_query,
        scope,
        move |store| candidate_indices_many(&ids, store),
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

fn normalize_article_ids(ids: &[u32]) -> Vec<u32> {
    ids.iter().copied().unique().sorted().collect()
}

fn article_ids_cache_key(ids: &[u32]) -> String {
    ids.iter().join(",")
}

fn search_cache_key(operation: &str, scope: &str, converted_query: &str, take: usize) -> String {
    format!("{operation}-{scope}-{converted_query}-take={take}")
}

fn candidate_indices(id: u32, store: &MessageStore) -> Vec<MessageIndex> {
    store.by_article.get(&id).cloned().unwrap_or_default()
}

fn candidate_indices_many(ids: &[u32], store: &MessageStore) -> Vec<MessageIndex> {
    ids.iter()
        .filter_map(|id| store.by_article.get(id))
        .flat_map(|messages| messages.iter().copied())
        .collect()
}

fn search_with_profile(
    label: &'static str,
    cache_key: String,
    raw_query: &str,
    converted_query: &str,
    scope: String,
    candidates: impl FnOnce(&MessageStore) -> Vec<MessageIndex>,
    scorer: impl SimilarityMethod,
    filter: impl for<'m> Fn(&StoredMessage<'m>) -> bool + Sync + Send,
    take: usize,
) -> Vec<MessageResult> {
    search_with_profile_inner(
        label,
        cache_key,
        raw_query,
        converted_query,
        scope,
        take,
        move || {
            let candidate_start = Instant::now();
            let store = MESSAGES.read().unwrap();
            let candidates = candidates(&store);
            let candidate_elapsed = candidate_start.elapsed();
            let (results, stats) = search_indices(&store, &candidates, scorer, filter, take);
            (results, stats, candidate_elapsed)
        },
    )
}

fn search_all_with_profile(
    label: &'static str,
    cache_key: String,
    raw_query: &str,
    converted_query: &str,
    scope: String,
    scorer: impl SimilarityMethod,
    filter: impl for<'m> Fn(&StoredMessage<'m>) -> bool + Sync + Send,
    take: usize,
) -> Vec<MessageResult> {
    search_with_profile_inner(
        label,
        cache_key,
        raw_query,
        converted_query,
        scope,
        take,
        move || {
            let candidate_start = Instant::now();
            let store = MESSAGES.read().unwrap();
            let candidate_elapsed = candidate_start.elapsed();
            let (results, stats) = search_all(&store, scorer, filter, take);
            (results, stats, candidate_elapsed)
        },
    )
}

fn search_with_profile_inner(
    label: &'static str,
    cache_key: String,
    raw_query: &str,
    converted_query: &str,
    scope: String,
    take: usize,
    search_miss: impl FnOnce() -> (Vec<MessageResult>, SearchStats, Duration),
) -> Vec<MessageResult> {
    let profile_enabled = search_profile_enabled();
    let raw_query = raw_query.to_string();
    let converted_query = converted_query.to_string();
    let total_start = Instant::now();
    let miss_scope = scope.clone();
    let miss_raw_query = raw_query.clone();
    let miss_converted_query = converted_query.clone();

    let (results, cache_status) = with_cache_status(cache_key, move || {
        let (results, stats, candidate_elapsed) = search_miss();
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

fn search_all(
    store: &MessageStore,
    scorer: impl SimilarityMethod,
    filter: impl for<'m> Fn(&StoredMessage<'m>) -> bool + Sync + Send,
    take: usize,
) -> (Vec<MessageResult>, SearchStats) {
    search(
        store.messages.len(),
        || {
            (0..store.messages.len())
                .into_par_iter()
                .map(|index| index as MessageIndex)
        },
        store,
        scorer,
        filter,
        take,
    )
}

fn search_indices(
    store: &MessageStore,
    candidates: &[MessageIndex],
    scorer: impl SimilarityMethod,
    filter: impl for<'m> Fn(&StoredMessage<'m>) -> bool + Sync + Send,
    take: usize,
) -> (Vec<MessageResult>, SearchStats) {
    search(
        candidates.len(),
        || candidates.par_iter().copied(),
        store,
        scorer,
        filter,
        take,
    )
}

fn search<'a, S, F, I, MakeIter>(
    candidates_len: usize,
    make_iter: MakeIter,
    store: &'a MessageStore,
    scorer: S,
    filter: F,
    take: usize,
) -> (Vec<MessageResult>, SearchStats)
where
    S: SimilarityMethod,
    F: for<'m> Fn(&StoredMessage<'m>) -> bool + Sync + Send,
    I: ParallelIterator<Item = MessageIndex>,
    MakeIter: Fn() -> I,
{
    let score_start = Instant::now();
    let top_results = if scorer.exact_matches_dominate_fuzzy() {
        let exact_results = collect_exact_results(store, make_iter(), &scorer, &filter, take);
        if exact_results.len() >= take {
            exact_results
        } else {
            exact_results.merge(collect_fuzzy_results(
                store,
                make_iter(),
                &scorer,
                &filter,
                take,
                true,
            ))
        }
    } else {
        collect_fuzzy_results(store, make_iter(), &scorer, &filter, take, false)
    };
    let score_elapsed = score_start.elapsed();
    let scored_len = top_results.scored;
    let exact_scored = top_results.exact_scored;
    let fuzzy_scored = top_results.fuzzy_scored;

    let sort_start = Instant::now();
    let results = top_results.into_sorted_vec();
    let sort_elapsed = sort_start.elapsed();

    let take_start = Instant::now();
    let results = results
        .into_iter()
        .take(take)
        .map(|scored| {
            let message = store.message_at(scored.index);
            let mut result: MessageResult = (&message).into();
            result.score = scored.score;
            result
        })
        .collect();
    let take_elapsed = take_start.elapsed();

    (
        results,
        SearchStats {
            candidates: candidates_len,
            scored: scored_len,
            exact_scored,
            fuzzy_scored,
            score_elapsed,
            sort_elapsed,
            take_elapsed,
        },
    )
}

fn collect_exact_results<S, F, I>(
    store: &MessageStore,
    candidates: I,
    scorer: &S,
    filter: &F,
    take: usize,
) -> TopScoredMessages
where
    S: SimilarityMethod,
    F: for<'m> Fn(&StoredMessage<'m>) -> bool + Sync + Send,
    I: ParallelIterator<Item = MessageIndex>,
{
    candidates
        .fold(
            || TopScoredMessages::new(take),
            |mut top_results, index| {
                let index = index as usize;
                let message = store.message_at(index);
                if filter(&message) {
                    if let Some(score) = scorer.exact_similarity(message.message) {
                        top_results.push_exact(index, message.correct, score);
                    }
                }
                top_results
            },
        )
        .reduce(
            || TopScoredMessages::new(take),
            |left, right| left.merge(right),
        )
}

fn collect_fuzzy_results<S, F, I>(
    store: &MessageStore,
    candidates: I,
    scorer: &S,
    filter: &F,
    take: usize,
    skip_exact: bool,
) -> TopScoredMessages
where
    S: SimilarityMethod,
    F: for<'m> Fn(&StoredMessage<'m>) -> bool + Sync + Send,
    I: ParallelIterator<Item = MessageIndex>,
{
    let global_cutoff = GlobalScoreCutoff::default();

    // Rayon splits the slice into worker-local chunks. Each fold builds a
    // local top-k heap, then reduce merges those local heaps into the final
    // top-k. Once any worker fills a local top-k, its worst score becomes a
    // safe global cutoff because at least `take` results already score that
    // high or higher.
    candidates
        .fold(
            || TopScoredMessages::new(take),
            |mut top_results, index| {
                let index = index as usize;
                let message = store.message_at(index);
                if filter(&message) {
                    let exact_score = scorer.exact_similarity(message.message);
                    if skip_exact && exact_score.is_some() {
                        return top_results;
                    }

                    if let Some(score) = exact_score {
                        top_results.push_exact(index, message.correct, score);
                        top_results.publish_score_cutoff(&global_cutoff);
                    } else {
                        let score = scorer.similarity(
                            message.message,
                            top_results.score_cutoff_with_global(&global_cutoff),
                        );
                        top_results.push_fuzzy(index, message.correct, score);
                        top_results.publish_score_cutoff(&global_cutoff);
                    }
                }
                top_results
            },
        )
        .reduce(
            || TopScoredMessages::new(take),
            |left, right| left.merge(right),
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

fn scored_message_order(amsg: &ScoredMessage, bmsg: &ScoredMessage) -> Ordering {
    score_correct_order(amsg.score, amsg.correct, bmsg.score, bmsg.correct)
}

fn score_correct_order(ascore: f64, acorrect: f32, bscore: f64, bcorrect: f32) -> Ordering {
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
            "[fscm-profile] op={label} cache={cache} {scope} query={raw_query:?} converted_len={converted_len} take={take} candidates={} scored={} exact={} fuzzy={} candidate_ms={:.3} score_ms={:.3} sort_ms={:.3} take_ms={:.3} total_ms={:.3}",
            stats.candidates,
            stats.scored,
            stats.exact_scored,
            stats.fuzzy_scored,
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

pub fn search_article(id: u32) -> Vec<MessageResult> {
    let store = MESSAGES.read().unwrap();
    store
        .by_article
        .get(&id)
        .into_iter()
        .flatten()
        .map(|&index| {
            let message = store.message_at(index as usize);
            (&message).into()
        })
        .collect()
}

pub fn article_lists() -> Vec<u32> {
    MESSAGES
        .read()
        .unwrap()
        .by_article
        .keys()
        .copied()
        .sorted()
        .collect()
}

#[cfg(test)]
fn article_candidate_count(id: u32) -> usize {
    MESSAGES
        .read()
        .unwrap()
        .by_article
        .get(&id)
        .map_or(0, Vec::len)
}

#[cfg(test)]
mod tests {
    use std::io::Cursor;
    use std::sync::Mutex;

    use super::*;

    static TEST_LOCK: LazyLock<Mutex<()>> = LazyLock::new(|| Mutex::new(()));

    fn test_message(article_id: u32, message: &str) -> Message {
        Message {
            article_id,
            page: 1,
            message: message.to_string(),
            #[cfg(feature = "raw")]
            raw: None,
            correct: 1.0,
            rects: [0.0, 0.0, 1.0, 1.0],
        }
    }

    fn test_scored_message(index: usize, correct: f32, score: f64) -> ScoredMessage {
        ScoredMessage {
            index,
            correct,
            score,
        }
    }

    fn reset_messages(messages: Vec<Message>) {
        *MESSAGES.write().unwrap() = MessageStore::from_messages(messages);
    }

    #[test]
    fn message_store_packs_messages_into_contiguous_bytes() {
        let store = MessageStore::from_messages(vec![
            test_message(10, "first"),
            test_message(20, "second"),
        ]);

        assert_eq!(store.message_bytes, b"firstsecond");
        assert_eq!(store.message_at(0).message, "first");
        assert_eq!(store.message_at(1).message, "second");
    }

    #[test]
    fn flat_message_file_roundtrips_into_message_store() {
        let messages = vec![
            test_message(10, "first"),
            test_message(10, "second"),
            test_message(20, "third"),
        ];
        let mut writer = FlatMessageWriter::default();
        for message in &messages {
            writer.push(message);
        }

        let mut bytes = Vec::new();
        writer.write_to(&mut bytes).unwrap();

        let mut store = MessageStore::default();
        store
            .extend_from_flat_reader(Cursor::new(bytes))
            .expect("flat message file should load");

        assert_eq!(store.message_at(0).message, "first");
        assert_eq!(store.message_at(1).message, "second");
        assert_eq!(store.message_at(2).message, "third");
        assert_eq!(store.by_article.get(&10).unwrap(), &vec![0, 1]);
        assert_eq!(store.by_article.get(&20).unwrap(), &vec![2]);
    }

    #[test]
    fn flat_message_writer_append_rebases_text_offsets() {
        let mut left = FlatMessageWriter::default();
        left.push(&test_message(10, "first"));
        let mut right = FlatMessageWriter::default();
        right.push(&test_message(20, "second"));

        left.append(right);

        let mut bytes = Vec::new();
        left.write_to(&mut bytes).unwrap();

        let mut store = MessageStore::default();
        store
            .extend_from_flat_reader(Cursor::new(bytes))
            .expect("merged flat writer should load");

        assert_eq!(store.message_at(0).message, "first");
        assert_eq!(store.message_at(1).message, "second");
        assert_eq!(store.by_article.get(&10).unwrap(), &vec![0]);
        assert_eq!(store.by_article.get(&20).unwrap(), &vec![1]);
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
    fn search_cache_distinguishes_take_for_all_search_variants() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset_messages(vec![
            test_message(10, "similarcachetakealpha"),
            test_message(20, "similarcachetakebeta"),
            test_message(10, "containscachetakealpha"),
            test_message(20, "containscachetakebeta"),
            test_message(10, "similarcachetakemanyalpha"),
            test_message(20, "similarcachetakemanybeta"),
            test_message(10, "containscachetakemanyalpha"),
            test_message(20, "containscachetakemanybeta"),
        ]);

        assert_eq!(search_similar(None, "similarcachetake", 1).len(), 1);
        assert_eq!(search_similar(None, "similarcachetake", 2).len(), 2);

        assert_eq!(
            search_partial_contains(None, "containscachetake", 1).len(),
            1
        );
        assert_eq!(
            search_partial_contains(None, "containscachetake", 2).len(),
            2
        );

        assert_eq!(
            search_similar_many(&[10, 20], "similarcachetakemany", 1).len(),
            1
        );
        assert_eq!(
            search_similar_many(&[10, 20], "similarcachetakemany", 2).len(),
            2
        );

        assert_eq!(
            search_partial_contains_many(&[10, 20], "containscachetakemany", 1).len(),
            1
        );
        assert_eq!(
            search_partial_contains_many(&[10, 20], "containscachetakemany", 2).len(),
            2
        );
    }

    #[test]
    fn skips_fuzzy_scoring_when_exact_matches_fill_take() {
        let store = MessageStore::from_messages(vec![
            test_message(1, "prefixneedle"),
            test_message(2, "suffixneedle"),
            test_message(3, "othercandidate"),
        ]);

        let (_results, stats) = search_all(&store, CachedPartialRatio::from("needle"), |_| true, 2);

        assert_eq!(stats.exact_scored, 2);
        assert_eq!(stats.fuzzy_scored, 0);
    }

    #[test]
    fn global_score_cutoff_keeps_highest_published_score() {
        let cutoff = GlobalScoreCutoff::default();

        assert_eq!(cutoff.get(), 0.0);

        cutoff.publish(75.0);
        cutoff.publish(50.0);
        assert_eq!(cutoff.get(), 75.0);

        cutoff.publish(88.5);
        assert_eq!(cutoff.get(), 88.5);
    }

    #[test]
    fn top_results_uses_higher_global_score_cutoff() {
        let cutoff = GlobalScoreCutoff::default();
        let top_results = TopScoredMessages::new(2);

        cutoff.publish(90.0);

        assert_eq!(top_results.score_cutoff_with_global(&cutoff), 90.0);
    }

    #[test]
    fn retain_top_results_limits_and_preserves_sort_order() {
        let mut results = vec![
            test_scored_message(1, 0.1, 10.0),
            test_scored_message(2, 0.2, 20.0),
            test_scored_message(3, 0.9, 20.0),
            test_scored_message(4, 0.9, 5.0),
        ];

        retain_top_results(&mut results, 2);

        let indices: Vec<_> = results.iter().map(|message| message.index).collect();
        assert_eq!(indices, vec![3, 2]);
    }

    #[test]
    fn collect_top_results_matches_full_top_k_order() {
        let results = vec![
            test_scored_message(1, 0.1, 10.0),
            test_scored_message(2, 0.2, 20.0),
            test_scored_message(3, 0.9, 20.0),
            test_scored_message(4, 0.9, 5.0),
            test_scored_message(5, 0.8, 30.0),
        ];
        let mut full_results = results.clone();
        retain_top_results(&mut full_results, 3);

        let top_results = collect_top_results(results, 3);

        let full_article_ids: Vec<_> = full_results.iter().map(|message| message.index).collect();
        let top_article_ids: Vec<_> = top_results.iter().map(|message| message.index).collect();

        assert_eq!(top_article_ids, full_article_ids);
    }

    #[test]
    fn merged_top_results_match_full_top_k_order() {
        let results = vec![
            test_scored_message(1, 0.1, 10.0),
            test_scored_message(2, 0.2, 20.0),
            test_scored_message(3, 0.9, 20.0),
            test_scored_message(4, 0.9, 5.0),
            test_scored_message(5, 0.8, 30.0),
            test_scored_message(6, 0.7, 25.0),
        ];
        let mut full_results = results.clone();
        retain_top_results(&mut full_results, 3);

        let mut left = TopScoredMessages::new(3);
        let mut right = TopScoredMessages::new(3);
        for message in results.iter().take(3) {
            left.push_scored(*message);
        }
        for message in results.iter().skip(3) {
            right.push_scored(*message);
        }
        let top_results = left.merge(right).into_sorted_vec();

        let full_article_ids: Vec<_> = full_results.iter().map(|message| message.index).collect();
        let top_article_ids: Vec<_> = top_results.iter().map(|message| message.index).collect();

        assert_eq!(top_article_ids, full_article_ids);
    }
}
