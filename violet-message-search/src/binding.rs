#![allow(warnings)]

use std::ffi::CString;
use std::os::raw::c_char;

include!(concat!(env!("OUT_DIR"), "/bindings.rs"));

#[link(name = "binding", kind = "static")]
extern "C" {}

pub trait SimilarityMethod: Sync {
    fn exact_similarity(&self, _message: &str) -> Option<f64> {
        None
    }

    fn similarity(&self, message: &str, score_cutoff: f64) -> f64;
}

static EMPTY_MESSAGE: [u8; 1] = [0];

fn message_parts(message: &str) -> (*const c_char, usize) {
    let bytes = message.as_bytes();
    let ptr = if bytes.is_empty() {
        EMPTY_MESSAGE.as_ptr()
    } else {
        bytes.as_ptr()
    };
    (ptr.cast(), bytes.len())
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
    fn similarity(&self, message: &str, score_cutoff: f64) -> f64 {
        let (message, message_len) = message_parts(message);
        unsafe { binding_similarity(self.scorer, message, message_len, score_cutoff) }
    }
}

pub struct CachedPartialRatio {
    scorer: *mut binding_CachedPartialRatioBinding,
    query: String,
}

unsafe impl Sync for CachedPartialRatio {}

impl CachedPartialRatio {
    pub fn from(query: &str) -> Self {
        let c_query = CString::new(query).unwrap();
        let scorer = unsafe { binding_create_partial(c_query.as_ptr()) };
        Self {
            scorer,
            query: query.to_string(),
        }
    }
}

impl SimilarityMethod for CachedPartialRatio {
    fn exact_similarity(&self, message: &str) -> Option<f64> {
        if !self.query.is_empty() && message.contains(&self.query) {
            Some(100.0)
        } else {
            None
        }
    }

    fn similarity(&self, message: &str, score_cutoff: f64) -> f64 {
        let (message, message_len) = message_parts(message);
        unsafe { binding_similarity_partial(self.scorer, message, message_len, score_cutoff) }
    }
}

#[cfg(test)]
mod tests {
    use super::{CachedPartialRatio, SimilarityMethod};
    use crate::binding::CachedRatio;

    fn test(src: &str, tar: &str) -> usize {
        CachedRatio::from(src).similarity(tar, 0.0) as usize
    }

    fn test_partial(src: &str, tar: &str) -> usize {
        CachedPartialRatio::from(src).similarity(tar, 0.0) as usize
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
    fn unittest_cached_ratio_handles_message_nul_byte() {
        assert_eq!(test("abcd", "abcd\0"), 88);
    }

    #[test]
    fn unittest_cached_ratio_respects_score_cutoff() {
        let scorer = CachedRatio::from("abcd");
        assert_eq!(scorer.similarity("abcde", 88.0) as usize, 88);
        assert_eq!(scorer.similarity("abcde", 89.0) as usize, 0);
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

    #[test]
    fn unittest_cached_partial_ratio_handles_message_nul_byte() {
        assert_eq!(test_partial("abcd", "xxabcd\0yy"), 100);
    }

    #[test]
    fn unittest_cached_partial_ratio_respects_score_cutoff() {
        let scorer = CachedPartialRatio::from("abcd");
        assert_eq!(scorer.similarity("acbd", 75.0) as usize, 75);
        assert_eq!(scorer.similarity("acbd", 76.0) as usize, 0);
    }

    #[test]
    fn unittest_cached_partial_ratio_reports_exact_substring_score() {
        let scorer = CachedPartialRatio::from("abcd");
        assert_eq!(scorer.exact_similarity("xxabcdyy"), Some(100.0));
        assert_eq!(scorer.exact_similarity("acbd"), None);
        assert_eq!(CachedRatio::from("abcd").exact_similarity("abcd"), None);
    }
}
