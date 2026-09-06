//! FSCM header validation and final-hit materialization.
use std::fs::File;
use std::io::{self, Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};

use super::super::{
    invalid_data, read_u32, read_u64, FlatRecord, MessageResult, ScoredMessage, FLAT_FLAG_RAW,
    FLAT_MAGIC, FLAT_RECORD_LEN, FLAT_VERSION,
};
use super::{MobileStore, HEADER_LEN};

pub(super) struct Source {
    pub(super) path: PathBuf,
    pub(super) count: usize,
    pub(super) bytes: u64,
    pub(super) text_start: u64,
}
impl Source {
    pub(super) fn open(path: &Path) -> io::Result<Self> {
        let mut file = File::open(path)?;
        let mut magic = [0; 8];
        file.read_exact(&mut magic)?;
        let version = read_u32(&mut file)?;
        let flags = read_u32(&mut file)?;
        if &magic != FLAT_MAGIC || version != FLAT_VERSION || flags & !FLAT_FLAG_RAW != 0 {
            return Err(invalid_data("unsupported FSCM header"));
        }
        let count = read_u64(&mut file)?;
        let bytes = read_u64(&mut file)?;
        let text_start = count
            .checked_mul(FLAT_RECORD_LEN as u64)
            .and_then(|v| v.checked_add(HEADER_LEN))
            .ok_or_else(|| invalid_data("FSCM size overflow"))?;
        if text_start.checked_add(bytes) != Some(file.metadata()?.len()) {
            return Err(invalid_data("FSCM file length mismatch"));
        }
        let count = usize::try_from(count).map_err(|_| invalid_data("too many records"))?;
        Ok(Self {
            path: path.to_path_buf(),
            count,
            bytes,
            text_start,
        })
    }
}
impl Source {
    fn read_record(&self, file: &mut File, index: usize) -> io::Result<FlatRecord> {
        file.seek(SeekFrom::Start(
            HEADER_LEN + index as u64 * FLAT_RECORD_LEN as u64,
        ))?;
        let record = FlatRecord::read_from(file)?;
        record.validate(self.bytes)?;
        Ok(record)
    }

    // Called only after materialize has checked the combined response allowance.
    #[cfg(feature = "raw")]
    fn read_raw_text(&self, file: &mut File, record: &FlatRecord) -> io::Result<String> {
        let mut bytes = vec![0; record.raw_len as usize];
        file.seek(SeekFrom::Start(self.text_start + record.raw_offset))?;
        file.read_exact(&mut bytes)?;
        String::from_utf8(bytes).map_err(|_| invalid_data("invalid raw UTF-8"))
    }
}

impl MobileStore {
    // Ranking uses indexes across all files; disk reads need an index within one file.
    fn locate_record(&self, mut global_index: usize) -> (usize, usize) {
        for (source_index, source) in self.sources.iter().enumerate() {
            if global_index < source.count {
                return (source_index, global_index);
            }
            global_index -= source.count;
        }
        unreachable!("ranked record must belong to a source")
    }

    pub(super) fn materialize(&self, hits: Vec<ScoredMessage>) -> io::Result<Vec<MessageResult>> {
        let mut results = Vec::with_capacity(hits.len());
        #[cfg(feature = "raw")]
        let mut raw_total = 0usize;
        let mut handles = self
            .sources
            .iter()
            .map(|s| File::open(&s.path))
            .collect::<io::Result<Vec<_>>>()?;
        for hit in hits {
            self.check_cancel()?;
            let (source_index, record_index) = self.locate_record(hit.index);
            let source = &self.sources[source_index];
            let file = &mut handles[source_index];
            let record = source.read_record(file, record_index)?;
            #[cfg(feature = "raw")]
            let raw = {
                raw_total = raw_total
                    .checked_add(record.raw_len as usize)
                    .ok_or_else(|| invalid_data("raw response overflow"))?;
                if raw_total > self.budget / 16 {
                    return Err(invalid_data("raw response exceeds mobile allowance"));
                }
                source.read_raw_text(file, &record)?
            };
            results.push(MessageResult {
                id: record.article_id,
                page: record.page,
                correct: record.correct,
                score: hit.score,
                rects: record.rects,
                #[cfg(feature = "raw")]
                raw,
            });
        }
        Ok(results)
    }
}
