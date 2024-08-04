use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};

use crate::message::MessageResult;

#[derive(Default)]
pub struct MemoryCache {
    cache: HashMap<String, Vec<MessageResult>>,
}

static CACHE_SIMILAR: LazyLock<Mutex<MemoryCache>> =
    LazyLock::new(|| Mutex::new(MemoryCache::default()));

static CACHE_CONTAINS: LazyLock<Mutex<MemoryCache>> =
    LazyLock::new(|| Mutex::new(MemoryCache::default()));

pub fn with_cache_similar(k: String, f: impl FnOnce() -> Vec<MessageResult>) -> Vec<MessageResult> {
    cache_inner(&CACHE_SIMILAR, k, f)
}

pub fn with_cache_contains(
    k: String,
    f: impl FnOnce() -> Vec<MessageResult>,
) -> Vec<MessageResult> {
    cache_inner(&CACHE_CONTAINS, k, f)
}

fn cache_inner(
    storage: &LazyLock<Mutex<MemoryCache>>,
    k: String,
    f: impl FnOnce() -> Vec<MessageResult>,
) -> Vec<MessageResult> {
    if let Some(hit) = storage.lock().unwrap().cache.get(&k) {
        return hit.clone();
    }

    let v = f();

    storage.lock().unwrap().cache.insert(k, v.clone());

    v
}
