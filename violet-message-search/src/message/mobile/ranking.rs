//! Full-corpus exact/fuzzy top-k ranking over bounded blocks.
use std::io;
use std::sync::atomic::Ordering as AtomicOrdering;

use rayon::iter::IntoParallelIterator;

use super::super::{
    collect_exact_results, collect_fuzzy_results_with_cutoff, ScoredMessage, StoredMessage,
    TopScoredMessages,
};
use super::{MobileStore, Scope};
use crate::binding::SimilarityMethod;

impl MobileStore {
    pub(super) fn rank(
        &self,
        scope: &Scope,
        scorer: impl SimilarityMethod,
        minimum_message_bytes: usize,
        take: usize,
    ) -> io::Result<Vec<ScoredMessage>> {
        let take = take.min(1000);
        let mut best_hits = TopScoredMessages::new(take);
        let filter = |m: &StoredMessage<'_>| {
            scope.includes(m.article_id) && m.message.len() >= minimum_message_bytes
        };
        let prefer_exact_matches = scorer.exact_matches_dominate_fuzzy();
        let mut exact_matches_found = 0usize;
        // Scan each block once. Exact hits dominate fuzzy scores, so once the
        // global heap is filled with exact hits no more fuzzy scoring is needed.
        // Earlier fuzzy hits are naturally evicted as better exact hits arrive.
        self.scan(|first_record, block| {
            if prefer_exact_matches {
                let block_hits = collect_exact_results(
                    block,
                    (0..block.messages.len() as u32).into_par_iter(),
                    &scorer,
                    &filter,
                    take,
                );
                exact_matches_found = exact_matches_found
                    .saturating_add(block_hits.len())
                    .min(take);
                merge_block_hits(&mut best_hits, block_hits, first_record);
            }
            if !prefer_exact_matches || exact_matches_found < take {
                let block_hits = collect_fuzzy_results_with_cutoff(
                    block,
                    (0..block.messages.len() as u32).into_par_iter(),
                    &scorer,
                    &filter,
                    take,
                    prefer_exact_matches,
                    best_hits.score_cutoff(),
                );
                merge_block_hits(&mut best_hits, block_hits, first_record);
            }
            Ok(())
        })?;
        self.planned.store(
            self.scanned.load(AtomicOrdering::Relaxed),
            AtomicOrdering::Relaxed,
        );
        Ok(best_hits.into_sorted_vec())
    }
}

// Block-local indexes must be rebased before the global heap or result reader sees them.
fn merge_block_hits(
    best_hits: &mut TopScoredMessages,
    block_hits: TopScoredMessages,
    first_record: usize,
) {
    for mut hit in block_hits.into_sorted_vec() {
        hit.index += first_record;
        best_hits.push_scored(hit);
    }
}
