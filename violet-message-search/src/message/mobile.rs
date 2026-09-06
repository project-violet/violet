//! Bounded, read-only scans of existing FSCM files. No corpus-sized allocations.
//!
//! This module owns the public API, memory allowances, and operation lifecycle.
//! `source` validates files and materializes hits, `scan` owns bounded I/O and
//! buffer handoff, and `ranking` combines block scores into full-corpus top-k.
use std::collections::BTreeSet;
use std::io;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering as AtomicOrdering};
use std::sync::{Mutex, OnceLock};

use serde::Serialize;

use super::{convert_query, invalid_data, MessageMeta, MessageResult, ScoredMessage};
use crate::binding::{CachedPartialRatio, CachedRatio};

mod ranking;
mod scan;
mod source;
use source::Source;

const MIB: usize = 1024 * 1024;
const HEADER_LEN: u64 = 32;
const MAX_QUERY_BYTES: usize = 4096;
const MAX_ARTICLE_RESULTS: usize = 10_000;
static STORE: OnceLock<MobileStore> = OnceLock::new();

pub enum Scope {
    All,
    Article(u32),
    Range(u32, u32),
    Many(Vec<u32>),
}

impl Scope {
    fn includes(&self, id: u32) -> bool {
        match self {
            Self::All => true,
            Self::Article(value) => id == *value,
            Self::Range(min, max) => *min <= id && id <= *max,
            Self::Many(ids) => ids.binary_search(&id).is_ok(),
        }
    }
}

pub struct MobileStore {
    sources: Vec<Source>,
    budget: usize,
    text_limit: usize,
    record_limit: usize,
    total: usize,
    gate: Mutex<()>,
    active: AtomicBool,
    cancelled: AtomicBool,
    scanned: AtomicUsize,
    planned: AtomicUsize,
}

#[derive(Serialize)]
pub struct Progress {
    enabled: bool,
    active: bool,
    cancelled: bool,
    scanned_records: usize,
    planned_records: usize,
    total_records: usize,
    memory_budget_mb: usize,
}

pub fn enabled() -> bool {
    STORE.get().is_some()
}

pub fn initialize(paths: &[PathBuf], budget_mb: usize) -> io::Result<()> {
    let store = MobileStore::open(paths, budget_mb)?;
    eprintln!(
        "[mobile] {} records; budget={} MiB; text buffer={} MiB; cache disabled",
        store.total,
        budget_mb,
        store.text_limit / MIB
    );
    STORE
        .set(store)
        .map_err(|_| invalid_data("mobile store already initialized"))
}

pub fn progress() -> Option<Progress> {
    STORE.get().map(|store| Progress {
        enabled: true,
        active: store.active.load(AtomicOrdering::Relaxed),
        cancelled: store.cancelled.load(AtomicOrdering::Relaxed),
        scanned_records: store.scanned.load(AtomicOrdering::Relaxed),
        planned_records: store.planned.load(AtomicOrdering::Relaxed),
        total_records: store.total,
        memory_budget_mb: store.budget / MIB,
    })
}

pub fn cancel() -> bool {
    if let Some(store) = STORE.get() {
        if store.active.load(AtomicOrdering::SeqCst) {
            store.cancelled.store(true, AtomicOrdering::SeqCst);
            return true;
        }
    }
    false
}

pub fn search(
    mut scope: Scope,
    query: &str,
    contains: bool,
    take: usize,
) -> io::Result<Vec<MessageResult>> {
    let store = STORE.get().expect("mobile not initialized");
    let _guard = store.begin()?;
    if query.len() > MAX_QUERY_BYTES {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "query exceeds mobile allowance",
        ));
    }
    if let Scope::Many(ids) = &mut scope {
        ids.sort_unstable();
        ids.dedup();
        if ids.is_empty() {
            store.planned.store(0, AtomicOrdering::Relaxed);
            return Ok(vec![]);
        }
    }
    let query = convert_query(query);
    if query.len() > MAX_QUERY_BYTES || query.contains('\0') {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "invalid or oversized query",
        ));
    }
    let hits = if contains {
        store.rank(&scope, CachedPartialRatio::from(&query), query.len(), take)?
    } else {
        store.rank(&scope, CachedRatio::from(&query), 0, take)?
    };
    store.materialize(hits)
}

pub fn article(id: u32) -> io::Result<Vec<MessageResult>> {
    let store = STORE.get().unwrap();
    let _guard = store.begin()?;
    let mut hits = Vec::new();
    store.scan_metadata(|index, record| {
        if record.article_id == id {
            if hits.len() >= MAX_ARTICLE_RESULTS {
                return Err(invalid_data(
                    "mobile article response exceeds 10000 records",
                ));
            }
            hits.push(ScoredMessage {
                index,
                score: 0.0,
                correct: record.correct,
            });
        }
        Ok(())
    })?;
    store.materialize(hits)
}

pub fn lists() -> io::Result<Vec<u32>> {
    let store = STORE.get().unwrap();
    let _guard = store.begin()?;
    let mut ids = BTreeSet::new();
    store.scan_metadata(|_, record| {
        ids.insert(record.article_id);
        if ids.len() > store.budget / 256 {
            return Err(invalid_data("mobile article list exceeds memory allowance"));
        }
        Ok(())
    })?;
    Ok(ids.into_iter().collect())
}

struct ActiveOperation<'a> {
    store: &'a MobileStore,
    _guard: std::sync::MutexGuard<'a, ()>,
}

impl Drop for ActiveOperation<'_> {
    fn drop(&mut self) {
        self.store.active.store(false, AtomicOrdering::SeqCst);
    }
}

impl MobileStore {
    fn open(paths: &[PathBuf], budget_mb: usize) -> io::Result<Self> {
        if !(128..=1024).contains(&budget_mb) {
            return Err(invalid_data("mobile budget must be 128..1024 MiB"));
        }
        let mut sources = Vec::new();
        let mut total = 0usize;
        for path in paths {
            let source = Source::open(path)?;
            let count = source.count;
            total = total
                .checked_add(count)
                .ok_or_else(|| invalid_data("too many records"))?;
            sources.push(source);
        }
        let budget = budget_mb * MIB;
        // Two blocks coexist. Each reserves 1/8 for metadata and 1/8 for text;
        // leave the remaining half for scoring, responses, and runtime overhead.
        let buffer_allowance = budget / 8;
        let text_limit = buffer_allowance.min(32 * MIB);
        let record_limit = (buffer_allowance / std::mem::size_of::<MessageMeta>()).min(1_048_576);
        Ok(Self {
            sources,
            budget,
            text_limit,
            record_limit,
            total,
            gate: Mutex::new(()),
            active: AtomicBool::new(false),
            cancelled: AtomicBool::new(false),
            scanned: AtomicUsize::new(0),
            planned: AtomicUsize::new(total),
        })
    }

    fn begin(&self) -> io::Result<ActiveOperation<'_>> {
        let guard = self.gate.try_lock().map_err(|_| {
            io::Error::new(io::ErrorKind::WouldBlock, "mobile search already running")
        })?;
        self.cancelled.store(false, AtomicOrdering::SeqCst);
        self.scanned.store(0, AtomicOrdering::Relaxed);
        self.planned.store(self.total, AtomicOrdering::Relaxed);
        self.active.store(true, AtomicOrdering::SeqCst);
        Ok(ActiveOperation {
            store: self,
            _guard: guard,
        })
    }

    fn check_cancel(&self) -> io::Result<()> {
        if self.cancelled.load(AtomicOrdering::Relaxed) {
            Err(io::Error::new(
                io::ErrorKind::Interrupted,
                "search cancelled",
            ))
        } else {
            Ok(())
        }
    }
}

#[cfg(test)]
mod tests;
