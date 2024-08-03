#![allow(warnings)]

use std::ffi::{CStr, CString};

include!(concat!(env!("OUT_DIR"), "/bindings.rs"));

pub struct CachedRatio {
    scorer: *mut binding_CachedRatioBinding,
}

impl CachedRatio {
    pub fn from(query: &str) -> Self {
        let c_query = CString::new(query).unwrap();
        let scorer = unsafe { binding_create(c_query.as_ptr()) };
        Self { scorer }
    }

    pub fn similarity(&self, message: &str) -> f64 {
        let c_query = CString::new(message).unwrap();
        unsafe { binding_similarity(self.scorer, c_query.as_ptr()) }
    }
}

#[cfg(test)]
mod tests {
    use crate::binding::CachedRatio;

    fn test(src: &str, tar: &str) -> usize {
        CachedRatio::from(src).similarity(tar) as usize
    }

    #[test]
    fn unittest_cached_ratio_simple() {
        assert_eq!(test("abcd", "abcd"), 100);
        assert_eq!(test("abcd", "abcde"), 88);
        assert_eq!(test("abcde", "abcd"), 88);
        assert_eq!(test("abcd", "acbd"), 75);
        assert_eq!(test("abcd", "efgh"), 0);
    }
}
