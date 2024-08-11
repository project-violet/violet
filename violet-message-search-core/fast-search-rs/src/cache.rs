use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};

use crate::message::MessageResult;

#[derive(Default)]
pub struct MemoryCache {
    cache: HashMap<String, Vec<MessageResult>>,
}

static CACHE_STORAGE: LazyLock<Mutex<MemoryCache>> =
    LazyLock::new(|| Mutex::new(MemoryCache::default()));

pub fn with_cache(k: String, f: impl FnOnce() -> Vec<MessageResult>) -> Vec<MessageResult> {
    cache_inner(&CACHE_STORAGE, k, f)
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
