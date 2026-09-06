//! Regression coverage for bounded scans, ranking, and operation lifecycle.
use std::fs::File;

use super::super::{
    search_all, FlatMessageWriter, Message, MessageStore, StoredMessage, TextRange,
};
use super::scan::validate_block_text;
use super::*;
#[test]
fn block_validation_checks_boundaries_and_ignores_unused_gaps() {
    let f = Fixture::new();
    let mut block = MessageStore::from_messages(f.messages[..2].to_vec());
    block.message_bytes = b"a\xffb".to_vec();
    block.messages[0].message = TextRange { offset: 10, len: 1 };
    block.messages[1].message = TextRange { offset: 12, len: 1 };
    validate_block_text(&mut block, 10).unwrap();
    assert_eq!(block.messages[1].message.offset, 2);
    block.messages.truncate(1);
    block.message_bytes = "éa".as_bytes().to_vec();
    assert!(validate_block_text(&mut block, 0).is_err());
    block.message_bytes = vec![0xff];
    assert!(validate_block_text(&mut block, 0).is_err());
}
struct Fixture {
    paths: Vec<PathBuf>,
    messages: Vec<Message>,
}
impl Fixture {
    fn new() -> Self {
        static NEXT: AtomicUsize = AtomicUsize::new(0);
        let key = NEXT.fetch_add(1, AtomicOrdering::Relaxed);
        let messages: Vec<_> = (0..80)
            .map(|i| Message {
                article_id: i % 4,
                page: i,
                message: ["xxabcdyy", "abcxefgh", "zzabdczz", "abcdefghijkl", "a", ""]
                    [i as usize % 6]
                    .into(),
                #[cfg(feature = "raw")]
                raw: Some(format!("original-{i}")),
                correct: (i + 1) as f32 / 100.,
                rects: [0., 0., 1., 1.],
            })
            .collect();
        let paths = (0..2)
            .map(|i| {
                std::env::temp_dir()
                    .join(format!("fscm-mobile-{}-{key}-{i}.fscm", std::process::id()))
            })
            .collect::<Vec<_>>();
        for (path, part) in paths.iter().zip(messages.chunks(40)) {
            let mut writer = FlatMessageWriter::default();
            for m in part {
                writer.push(m);
            }
            writer.write_to(&mut File::create(path).unwrap()).unwrap();
        }
        Self { paths, messages }
    }
    fn store(&self) -> MobileStore {
        let mut s = MobileStore::open(&self.paths, 128).unwrap();
        s.text_limit = 64; // Force many boundaries and nonzero text offsets.
        s
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        for p in &self.paths {
            let _ = std::fs::remove_file(p);
        }
    }
}
fn keys(results: Vec<MessageResult>) -> Vec<(u32, u32, f64, f32)> {
    results
        .into_iter()
        .map(|r| (r.id, r.page, r.score, r.correct))
        .collect()
}
#[test]
fn bounded_multifile_scans_match_resident_search() {
    let f = Fixture::new();
    let s = f.store();
    let resident = MessageStore::from_messages(f.messages.clone());
    for scope in [
        Scope::All,
        Scope::Article(2),
        Scope::Range(1, 2),
        Scope::Many(vec![0, 3]),
        Scope::Many(vec![]),
    ] {
        for query in ["abcd", "nosuchquery", ""] {
            for take in [3, 30] {
                let filter = |m: &StoredMessage<'_>| {
                    scope.includes(m.article_id) && query.len() <= m.message.len()
                };
                let expected =
                    search_all(&resident, CachedPartialRatio::from(query), filter, take).0;
                let hits = s
                    .rank(&scope, CachedPartialRatio::from(query), query.len(), take)
                    .unwrap();
                let actual = s.materialize(hits).unwrap();
                #[cfg(feature = "raw")]
                for r in &actual {
                    assert_eq!(r.raw, format!("original-{}", r.page));
                }
                assert_eq!(keys(actual), keys(expected));
                let expected = search_all(
                    &resident,
                    CachedRatio::from(query),
                    |m| scope.includes(m.article_id),
                    take,
                )
                .0;
                let actual = s
                    .materialize(s.rank(&scope, CachedRatio::from(query), 0, take).unwrap())
                    .unwrap();
                assert_eq!(keys(actual), keys(expected));
            }
        }
    }
}
#[test]
fn blocks_are_bounded_and_metadata_scan_keeps_global_indices() {
    let f = Fixture::new();
    let s = f.store();
    let mut seen = 0;
    s.scan(|base, block| {
        assert_eq!(base, seen);
        assert!(block.message_bytes.len() <= 64);
        assert!(block.by_article.is_empty());
        assert!(block.messages.len() <= s.record_limit);
        seen += block.messages.len();
        Ok(())
    })
    .unwrap();
    assert_eq!(seen, 80);
    s.scan_metadata(|index, r| {
        assert_eq!(r.page as usize, index);
        Ok(())
    })
    .unwrap();
}
#[test]
fn rejects_concurrency_and_cancellation_without_partial_results() {
    let f = Fixture::new();
    let s = f.store();
    let active = s.begin().unwrap();
    assert_eq!(s.begin().err().unwrap().kind(), io::ErrorKind::WouldBlock);
    s.cancelled.store(true, AtomicOrdering::Relaxed);
    assert_eq!(
        s.scan(|_, _| Ok(())).unwrap_err().kind(),
        io::ErrorKind::Interrupted
    );
    drop(active);
    assert!(!s.active.load(AtomicOrdering::Relaxed));
    let _again = s.begin().unwrap();
    assert!(!s.cancelled.load(AtomicOrdering::Relaxed));
}
#[test]
fn rejects_truncated_files_and_oversized_messages() {
    let f = Fixture::new();
    let mut s = f.store();
    s.text_limit = 2;
    assert!(s.scan(|_, _| Ok(())).is_err());
    File::options()
        .write(true)
        .open(&f.paths[0])
        .unwrap()
        .set_len(32)
        .unwrap();
    assert!(MobileStore::open(&f.paths, 128).is_err());
    assert!(MobileStore::open(&[], 4096).is_err());
}

#[test]
fn pipeline_joins_reader_on_consumer_failure_or_mid_scan_cancel() {
    let f = Fixture::new();
    let s = f.store();
    let error = s
        .scan(|_, _| Err(io::Error::other("consumer failed")))
        .unwrap_err();
    assert_eq!(error.to_string(), "consumer failed");
    let _active = s.begin().unwrap();
    let mut blocks = 0;
    let error = s
        .scan(|_, _| {
            blocks += 1;
            s.cancelled.store(true, AtomicOrdering::Relaxed);
            Ok(())
        })
        .unwrap_err();
    assert_eq!(error.kind(), io::ErrorKind::Interrupted);
    assert_eq!(blocks, 1);
}
