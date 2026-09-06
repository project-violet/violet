//! Bounded disk scans and the two-buffer reader/scorer handoff.
use std::fs::File;
use std::io::{self, BufReader, Read, Seek, SeekFrom};
use std::sync::atomic::Ordering as AtomicOrdering;
use std::time::{Duration, Instant};

use super::super::{
    invalid_data, millis, search_profile_enabled, FlatRecord, MessageMeta, MessageStore, TextRange,
    FLAT_RECORD_LEN,
};
use super::{MobileStore, HEADER_LEN, MIB};

// Cancellation/progress interval for metadata decoding, not the buffer capacity.
const METADATA_CHECK_INTERVAL: usize = 65_536;

impl MobileStore {
    pub(super) fn scan_metadata(
        &self,
        mut visit: impl FnMut(usize, FlatRecord) -> io::Result<()>,
    ) -> io::Result<()> {
        let mut base = 0;
        for source in &self.sources {
            let mut file = BufReader::with_capacity(MIB, File::open(&source.path)?);
            file.seek(SeekFrom::Start(HEADER_LEN))?;
            for index in 0..source.count {
                if index % METADATA_CHECK_INTERVAL == 0 {
                    self.check_cancel()?;
                }
                let record = FlatRecord::read_from(&mut file)?;
                record.validate(source.bytes)?;
                visit(base + index, record)?;
                if index % METADATA_CHECK_INTERVAL == 0 {
                    self.scanned.store(base + index, AtomicOrdering::Relaxed);
                    if index > 0 {
                        release_pages(
                            file.get_ref(),
                            HEADER_LEN
                                + (index - METADATA_CHECK_INTERVAL) as u64 * FLAT_RECORD_LEN as u64,
                            METADATA_CHECK_INTERVAL as u64 * FLAT_RECORD_LEN as u64,
                        );
                    }
                }
            }
            base += source.count;
            release_pages(
                file.get_ref(),
                HEADER_LEN,
                source.count as u64 * FLAT_RECORD_LEN as u64,
            );
        }
        self.scanned.store(self.total, AtomicOrdering::Relaxed);
        Ok(())
    }
    pub(super) fn scan(
        &self,
        mut visit: impl FnMut(usize, &MessageStore) -> io::Result<()>,
    ) -> io::Result<()> {
        let started = Instant::now();
        let mut score_time = Duration::ZERO;
        // Two reusable blocks: the scorer owns one while the reader fills the
        // other. Transfer ownership rather than copying every record/text byte.
        let result = std::thread::scope(|threads| {
            let (ready_blocks_sender, ready_blocks) = std::sync::mpsc::sync_channel(0);
            let (empty_blocks_sender, empty_blocks) = std::sync::mpsc::sync_channel(1);
            empty_blocks_sender.send(MessageStore::default()).unwrap();
            let producer = threads.spawn(move || {
                self.read_blocks(|base, block| {
                    ready_blocks_sender.send((base, block)).map_err(|_| {
                        io::Error::new(io::ErrorKind::Interrupted, "scan consumer stopped")
                    })?;
                    empty_blocks.recv().map_err(|_| {
                        io::Error::new(io::ErrorKind::Interrupted, "scan consumer stopped")
                    })
                })
            });
            let scoring_result: io::Result<()> = (|| {
                for (base, block) in &ready_blocks {
                    self.check_cancel()?;
                    let score_start = Instant::now();
                    visit(base, &block)?;
                    score_time += score_start.elapsed();
                    self.scanned
                        .fetch_add(block.messages.len(), AtomicOrdering::Relaxed);
                    // The reader may already have completed its final block.
                    let _ = empty_blocks_sender.send(block);
                }
                Ok(())
            })();
            // Close BOTH channels before joining: the reader may be waiting on either.
            drop(ready_blocks);
            drop(empty_blocks_sender);
            let reading_result = producer
                .join()
                .map_err(|_| io::Error::other("scan reader panicked"))?;
            scoring_result?;
            reading_result
        });
        if search_profile_enabled() {
            eprintln!(
                "[mobile-pipeline] total_ms={:.1} score_ms={:.1}",
                millis(started.elapsed()),
                millis(score_time)
            );
        }
        result
    }
    // Reader loop: fill metadata, load text, hand off the block, then release pages.
    fn read_blocks(
        &self,
        mut exchange_block: impl FnMut(usize, MessageStore) -> io::Result<MessageStore>,
    ) -> io::Result<()> {
        let mut file_base = 0;
        let mut decode_time = Duration::ZERO;
        let mut text_time = Duration::ZERO;
        let mut transfer_wait = Duration::ZERO;
        let mut release_time = Duration::ZERO;

        for source in &self.sources {
            let mut reader = SourceReader::open(self, source)?;
            let mut block = MessageStore::default();
            block.messages.reserve(self.record_limit);
            block.message_bytes = Vec::with_capacity(self.text_limit);

            while reader.has_more_records() {
                self.check_cancel()?;
                let started = Instant::now();
                let text_range = reader.fill_metadata(&mut block)?;
                decode_time += started.elapsed();

                let started = Instant::now();
                reader.load_text(&mut block, &text_range)?;
                text_time += started.elapsed();

                let first_record = file_base + reader.next_record;
                let record_count = block.messages.len();
                let started = Instant::now();
                // Ownership moves to the scorer; a spare buffer comes back.
                block = exchange_block(first_record, block)?;
                transfer_wait += started.elapsed();

                let started = Instant::now();
                reader.release_and_advance(text_range, record_count);
                release_time += started.elapsed();
            }
            file_base += source.count;
        }
        if search_profile_enabled() {
            eprintln!(
                "[mobile-profile] metadata_ms={:.1} text_ms={:.1} transfer_wait_ms={:.1} release_ms={:.1}",
                millis(decode_time), millis(text_time), millis(transfer_wait), millis(release_time)
            );
        }
        Ok(())
    }
}

// All cursor state belongs to one file reader. Callers only supply a reusable block.
struct SourceReader<'a> {
    store: &'a MobileStore,
    source: &'a super::Source,
    metadata: BufReader<File>,
    text: File,
    pending_record: Option<FlatRecord>,
    next_record: usize,
}

impl<'a> SourceReader<'a> {
    fn open(store: &'a MobileStore, source: &'a super::Source) -> io::Result<Self> {
        let mut metadata = BufReader::with_capacity(MIB, File::open(&source.path)?);
        metadata.seek(SeekFrom::Start(HEADER_LEN))?;
        Ok(Self {
            store,
            source,
            metadata,
            text: File::open(&source.path)?,
            pending_record: None,
            next_record: 0,
        })
    }

    fn has_more_records(&self) -> bool {
        self.next_record < self.source.count
    }

    fn load_text(
        &mut self,
        block: &mut MessageStore,
        range: &std::ops::Range<u64>,
    ) -> io::Result<()> {
        self.text
            .seek(SeekFrom::Start(self.source.text_start + range.start))?;
        self.text.read_exact(&mut block.message_bytes)?;
        validate_block_text(block, range.start)
    }

    fn release_and_advance(&mut self, text_range: std::ops::Range<u64>, record_count: usize) {
        release_pages(
            &self.text,
            self.source.text_start + text_range.start,
            text_range.end - text_range.start,
        );
        release_pages(
            self.metadata.get_ref(),
            HEADER_LEN + self.next_record as u64 * FLAT_RECORD_LEN as u64,
            record_count as u64 * FLAT_RECORD_LEN as u64,
        );
        self.next_record += record_count;
    }

    // Decode only enough metadata to fit one block's record and text allowances.
    // Keep the first record of the next block pending without seeking backwards.
    fn fill_metadata(&mut self, block: &mut MessageStore) -> io::Result<std::ops::Range<u64>> {
        let remaining = self.source.count - self.next_record;
        block.messages.clear();
        block.messages.reserve(self.store.record_limit);
        block.message_bytes.reserve(
            self.store
                .text_limit
                .saturating_sub(block.message_bytes.len()),
        );
        let mut text_start = u64::MAX;
        let mut text_end = 0;
        while block.messages.len() < remaining && block.messages.len() < self.store.record_limit {
            if block.messages.len() % METADATA_CHECK_INTERVAL == 0 {
                self.store.check_cancel()?;
            }
            let record = match self.pending_record.take() {
                Some(r) => r,
                None => FlatRecord::read_from(&mut self.metadata)?,
            };
            record.validate(self.source.bytes)?;
            if !record.correct.is_finite() {
                return Err(invalid_data("non-finite correctness"));
            }
            let extended_start = text_start.min(record.message_offset);
            let extended_end = text_end.max(record.message_offset + u64::from(record.message_len));
            if extended_end - extended_start > self.store.text_limit as u64 {
                if block.messages.is_empty() {
                    return Err(invalid_data("message exceeds mobile text buffer"));
                }
                self.pending_record = Some(record);
                break;
            }
            text_start = extended_start;
            text_end = extended_end;
            block.messages.push(MessageMeta {
                article_id: record.article_id,
                page: record.page,
                message: TextRange {
                    offset: record.message_offset,
                    len: record.message_len,
                },
                #[cfg(feature = "raw")]
                raw: None,
                correct: record.correct,
                rects: record.rects,
            });
        }
        let length = (text_end - text_start) as usize;
        block.message_bytes.resize(length, 0);
        Ok(text_start..text_end)
    }
}

pub(super) fn validate_block_text(block: &mut MessageStore, low: u64) -> io::Result<()> {
    // Validate contiguous UTF-8 once, then only check each record's boundaries.
    // Gaps/raw bytes need not be valid UTF-8: retain the per-record fallback.
    let text = std::str::from_utf8(&block.message_bytes).ok();
    for meta in &mut block.messages {
        meta.message.offset -= low;
        let start = meta.message.offset as usize;
        let end = start + meta.message.len as usize;
        if let Some(text) = text {
            if !text.is_char_boundary(start) || !text.is_char_boundary(end) {
                return Err(invalid_data("invalid message UTF-8 boundary"));
            }
        } else {
            std::str::from_utf8(&block.message_bytes[start..end])
                .map_err(|_| invalid_data("invalid message UTF-8"))?;
        }
    }
    Ok(())
}
// Advisory only: keep a sequential scan from retaining the whole corpus in
// Linux's shared file cache. This does not impose an OS memory limit.
fn release_pages(file: &File, offset: u64, length: u64) {
    #[cfg(any(target_os = "linux", target_os = "android"))]
    {
        use std::os::fd::AsRawFd;
        if length > 0 && offset <= i64::MAX as u64 && length <= i64::MAX as u64 {
            unsafe {
                libc::posix_fadvise(
                    file.as_raw_fd(),
                    offset as _,
                    length as _,
                    libc::POSIX_FADV_DONTNEED,
                );
            }
        }
    }
    #[cfg(not(any(target_os = "linux", target_os = "android")))]
    let _ = (file, offset, length);
}
