#![allow(warnings)]

use std::ffi::{CStr, CString};
use std::ptr::NonNull;

include!(concat!(env!("OUT_DIR"), "/bindings.rs"));

pub trait SimilarityMethod: Sync {
    fn filter(&self, message: &str) -> bool;

    fn similarity(&self, message: &str) -> f64;
}

pub struct CachedRatio {
    scorer: *mut binding_CachedRatioBinding,
}

unsafe impl Sync for CachedRatio {}

impl CachedRatio {
    pub fn from(query: &str) -> Self {
        let c_query = CString::new(query).unwrap();
        let scorer = unsafe { binding_create(c_query.as_ptr()) };
        Self { scorer }
    }
}

impl SimilarityMethod for CachedRatio {
    fn filter(&self, _: &str) -> bool {
        true
    }

    fn similarity(&self, message: &str) -> f64 {
        let c_query = CString::new(message).unwrap();
        unsafe { binding_similarity(self.scorer, c_query.as_ptr()) }
    }
}

pub struct CachedPartialRatio {
    query_len: usize,
    scorer: *mut binding_CachedPartialRatioBinding,
}

unsafe impl Sync for CachedPartialRatio {}

impl CachedPartialRatio {
    pub fn from(query: &str) -> Self {
        let c_query = CString::new(query).unwrap();
        let scorer = unsafe { binding_create_partial(c_query.as_ptr()) };
        Self {
            query_len: query.len(),
            scorer,
        }
    }
}

impl SimilarityMethod for CachedPartialRatio {
    fn filter(&self, message: &str) -> bool {
        self.query_len <= message.len()
    }

    fn similarity(&self, message: &str) -> f64 {
        let c_query = CString::new(message).unwrap();
        unsafe { binding_similarity_partial(self.scorer, c_query.as_ptr()) }
    }
}

#[cfg(test)]
mod tests {
    use super::{CachedPartialRatio, SimilarityMethod};
    use crate::binding::CachedRatio;

    fn test(src: &str, tar: &str) -> usize {
        CachedRatio::from(src).similarity(tar) as usize
    }

    fn test_partial(src: &str, tar: &str) -> usize {
        CachedPartialRatio::from(src).similarity(tar) as usize
    }

    #[test]
    fn unittest_cached_ratio_simple() {
        assert_eq!(test("abcd", "abcd"), 100);
        assert_eq!(test("abcd", "abcde"), 88);
        assert_eq!(test("abcde", "abcd"), 88);
        assert_eq!(test("abcd", "acbd"), 75);
        assert_eq!(test("abcd", "efgh"), 0);
    }

    #[test]
    fn unittest_cached_partial_ratio_simple() {
        assert_eq!(test_partial("abcd", "abcd"), 100);
        assert_eq!(test_partial("abcd", "abcde"), 100);
        assert_eq!(test_partial("abcde", "abcd"), 100);
        assert_eq!(test_partial("abcd", "acbd"), 75);
        assert_eq!(test_partial("abcdefg", "cbedgf"), 54);
        assert_eq!(test_partial("abcd", "efgh"), 0);
    }
}
