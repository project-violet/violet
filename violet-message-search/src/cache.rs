use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};

use crate::message::MessageResult;

#[derive(Default)]
pub struct MemoryCache {
    cache: HashMap<String, Vec<MessageResult>>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CacheStatus {
    Hit,
    Miss,
}

static CACHE_STORAGE: LazyLock<Mutex<MemoryCache>> =
    LazyLock::new(|| Mutex::new(MemoryCache::default()));

pub fn with_cache_status(
    k: String,
    f: impl FnOnce() -> Vec<MessageResult>,
) -> (Vec<MessageResult>, CacheStatus) {
    cache_inner_with_status(&CACHE_STORAGE, k, f)
}

fn cache_inner_with_status<F>(
    storage: &LazyLock<Mutex<MemoryCache>, F>,
    k: String,
    f: impl FnOnce() -> Vec<MessageResult>,
) -> (Vec<MessageResult>, CacheStatus)
where
    F: FnOnce() -> Mutex<MemoryCache>,
{
    if let Some(hit) = storage.lock().unwrap().cache.get(&k) {
        return (hit.clone(), CacheStatus::Hit);
    }

    let v = f();

    storage.lock().unwrap().cache.insert(k, v.clone());

    (v, CacheStatus::Miss)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cache_status_reports_miss_then_hit() {
        let storage = LazyLock::new(|| Mutex::new(MemoryCache::default()));
        let mut calls = 0;

        let (_, first_status) = cache_inner_with_status(&storage, "key".to_string(), || {
            calls += 1;
            Vec::new()
        });
        let (_, second_status) = cache_inner_with_status(&storage, "key".to_string(), || {
            calls += 1;
            Vec::new()
        });

        assert_eq!(first_status, CacheStatus::Miss);
        assert_eq!(second_status, CacheStatus::Hit);
        assert_eq!(calls, 1);
    }
}
