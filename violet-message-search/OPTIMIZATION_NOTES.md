# Message Search Optimization Notes

Date: 2026-07-05

This note records the optimization attempts around `contains` / `wcontains` in
`violet-message-search`. It is intentionally a working note, not a final design
document.

## Starting Point

The first suspicion was that `wcontains` and `wcontains-many` were slow because
they were doing extra work per selected work. Profiling showed the opposite for
the message-search service itself:

- `wcontains-many` over a few hundred works usually finished in a few
  milliseconds inside `violet-message-search`.
- The slow path was mostly the web/backend route around it, especially graph
  lookup and author work-id lookup before backend-side caches were added.
- For full `contains`, the real bottleneck was scanning tens of millions of
  messages and fuzzy-scoring millions of candidates.

Representative full `contains` profile after earlier top-k and candidate
improvements:

```text
contains: query A (take=500)
candidates=45904212 scored=14070567 exact=1 fuzzy=14070566 score_ms~=1.7-1.9s

contains: query B (take=500)
candidates=45904212 scored=19858232 exact=110 fuzzy=19858122 score_ms~=1.5s
```

So the remaining hot path is effectively:

```text
millions of fuzzy candidates * RapidFuzz CachedPartialRatio::similarity
```

## Profiling Added

Two profiling layers were added.

`FSCM_PROFILE=1` logs search-level phases from Rust:

- candidates
- scored
- exact / fuzzy counts
- candidate / score / sort / take timings

`FSCM_RF_PROFILE=1` adds C++ RapidFuzz counters:

- `similarity_calls`
- `impl_calls`
- `window_calls`, `window_iters`, `distance_calls`
- `prefix_ratio_calls`, `suffix_ratio_calls`
- prefix / suffix / window elapsed time

There is also an ignored unit profiling helper:

```powershell
cargo test rapid_fuzz_partial_ratio_profile_sample -- --ignored --nocapture
```

Useful knobs:

```powershell
$env:FSCM_RF_PROFILE_SAMPLE='2000000'
$env:FSCM_RF_PROFILE_CUTOFF='80'
$env:FSCM_RF_PROFILE_QUERY='example-query'
```

The unit profile is synthetic and should be used for A/B checks only. The server
profile is the source of truth for real workload impact.

## Optimizations Tried

### Avoid sorting all scored results

The full-sort path was replaced with top-k retention. This moved `sort_ms` from
hundreds or thousands of milliseconds to effectively zero for full `contains`.
This was a clear win and does not change result ordering because the same
score/correctness order is preserved for the retained top-k.

### Avoid candidate vector clone for full search

For full search, the code now searches `store.messages` directly instead of
cloning all `Arc<Message>` values into a candidate vector. This removed
`candidate_ms` from the hot full-search path.

### Avoid CString copy per message

The Rust binding now passes message pointer + length to C++ instead of creating
a `CString` for every candidate. This reduced `score_ms` noticeably in the full
scan case and also made NUL bytes safe in message text.

### Exact-first contains

For `contains`, exact substring matches are scored as `100` before fuzzy scoring.
If exact matches already fill `take`, fuzzy scoring can be skipped completely.

This is extremely effective for short/common exact queries, where exact matches
can fill the requested result count. It has little effect on rare long queries
with only a few exact matches.

### Global cutoff across Rayon workers

Each worker keeps a local top-k, and a shared atomic global cutoff publishes the
best known worst-score once a worker has enough results. This gives RapidFuzz a
higher `score_cutoff` earlier, allowing internal early exits. The improvement was
small but measurable and should be lossless because candidates below an already
filled top-k cutoff cannot enter the final top-k.

### Compact in-memory message store

The initial in-memory layout kept every message behind an `Arc<Message>` and
stored cloned `Arc`s in both the global message list and the per-article map.
That layout avoided string duplication, but it still created one heap allocation
per message plus atomic reference-count traffic whenever a result entered the
top-k heap.

The store was first changed to keep messages in one contiguous `Vec<Message>`
and to store per-article candidates as compact message indexes. The top-k heap
now keeps only the message index, score, and correctness value, then resolves
the index only when producing final API results.

That still left one heap allocation per `Message.message` string. The next
step packs message text into a single byte arena:

```text
Vec<MessageMeta>      // article id, page, text range, score metadata
Vec<u8> message_bytes // all normalized message text
```

The hot search loop now carries compact message indexes, builds a temporary
`StoredMessage` view from `MessageMeta + message_bytes`, and passes the borrowed
`&str` to RapidFuzz. API JSON field names and route shapes are unchanged.

The stored payload was also compacted for the default build:

- `MessageRaw` is present only with the `raw` feature.
- article id and page are stored as `u32`.
- OCR correctness and rectangle coordinates are stored as `f32`.

This targets both startup memory and full-scan search speed. Startup avoids
millions of per-message `Arc` allocations and steady-state message `String`
headers/allocations. Search avoids pointer chasing, atomic `Arc` clones in the
top-k heap, and some memory bandwidth from oversized metadata.

### Flat binary startup format

The arena store reduced steady-state memory, but JSON startup still had a high
temporary peak because each split was loaded as:

```text
JSON bytes -> Vec<Message> with per-message String allocations -> arena store
```

The `.fscm` format stores the runtime layout directly:

```text
magic/version/flags/counts
fixed-size MessageMeta records
contiguous normalized message bytes
```

`raw-compress` writes `merged-N.fscm` files, and the server loader accepts only
`.fscm` paths. Loading the flat file appends records directly to `MessageStore`
and reads the byte block directly into `message_bytes`, avoiding the
intermediate `Vec<Message>` and per-message `String` allocations.

The fscm compression path is intentionally optimized for throughput rather than
low memory use. Raw files are parsed and normalized in parallel, each worker
builds a local flat writer, and the results are merged by split before the final
files are written. This can use substantially more memory while generating the
dataset, but it moves the expensive JSON parse and Hangul normalization work off
the sequential path.

The format is intentionally simple and little-endian. It does not depend on Rust
struct layout or padding, but it keeps metadata and bytes in mmap-friendly
contiguous sections so a future loader can replace the read path with mmap
without changing the generated file shape.

### Prefix/suffix edge upper bound

RapidFuzz `partial_ratio` checks full-length windows and then shorter prefix /
suffix edge alignments. For those edge alignments, a length-only upper bound is:

```text
max_score = 200 * min(query_len, edge_len) / (query_len + edge_len)
```

If this bound cannot beat the current cutoff or current best score, the edge
candidate is skipped before calling `cached_ratio.similarity`.

This removed a large portion of prefix/suffix `ratio` calls. In the synthetic
profile, prefix+suffix ratio calls dropped by roughly two thirds. Real server
impact was visible but not proportional because the window/distance pass remains
significant.

### Leaf-window distance cutoff

A later attempt passed a cutoff into RapidFuzz `cached_indel.distance`.

Applying the cutoff to every window was a failure. `scores[]` is also used for
window pruning, and saturated distances made pruning more conservative. In the
unit profile, `window_iters` exploded and runtime got much worse.

The retained version applies distance cutoff only when `cell_diff == 1`, i.e. at
leaf windows that will not be split again. At that point a saturated distance is
used only to decide whether the candidate can improve `cutoff_dist`, so it should
not affect the final score/alignment.

Synthetic A/B with `FSCM_RF_PROFILE_SAMPLE=2000000`:

```text
without leaf cutoff: wall_ms~=2539
with leaf cutoff:    wall_ms~=1886
```

This did not always translate strongly to the observed server query timings, but
it is a small, localized, lossless-looking optimization.

## Attempts Rejected Or Deferred

### Full-window distance cutoff

Rejected because it increased window exploration dramatically by storing
saturated values in `scores[]`.

### Range creation delay in prefix/suffix loops

Tried to check `s1_char_set` before constructing `Range`. In the synthetic
profile it was neutral to slower, likely because the extra iterator arithmetic
and branch shape outweighed the tiny saved object creation. Reverted.

### AVX2 build experiment

Tried as a build-level experiment, but the observed search profile did not
improve enough to keep it.

### Thread-local scratch reuse for partial_ratio

Tried reusing the temporary `scores`, `windows`, and `new_windows` vectors used
by the RapidFuzz `partial_ratio_impl` window pass. The goal was to remove
per-candidate vector allocation from the C++ FFI hot path while keeping the
same scoring semantics.

Because `RapidFuzz-cpp` is a submodule, keeping the experiment local to this
repository required a binding-local helper that mirrored the RapidFuzz
`partial_ratio_impl` logic and swapped only the temporary storage for
thread-local scratch buffers. This avoided shared mutable state across Rayon
workers, but it duplicated too much RapidFuzz internals in `cxx/main.cpp`.

Representative server runs with the scratch path enabled:

```text
case A fuzzy=19858227 score_ms=1622.514
case B fuzzy=14070567 score_ms=1965.427
```

The result was not clearly better than the existing implementation. This
suggests that allocator churn is not a major part of the remaining hot path;
the dominant cost is still the actual Indel/LCS distance work in RapidFuzz.
The experiment was reverted because the complexity and duplicated internals did
not justify the unclear gain.

### Upper-bound dry run over candidates

A previous proven-bound dry run showed potential skips, but the bound-checking
cost made total runtime worse in that form. It should not be enabled without a
cheaper precomputed representation.

### Rust byte-overlap upper-bound pruning

Tried a Rust-side branch-and-bound check before calling RapidFuzz for
`CachedPartialRatio`. The bound was based on byte multiset overlap:

```text
overlap = sum(min(query_byte_count[b], message_byte_count[b]))
upper_bound ~= 200 * overlap / (min(query_len, message_len) + overlap)
```

This is intended to be lossless for the current byte-based C++ binding: any
partial-ratio window/edge comparison is still bounded by the maximum possible
LCS implied by query/message byte overlap. Candidates were skipped only when the
upper bound was strictly below the current top-k cutoff.

Representative server results:

```text
query A scored=8852873  bound_pruned=148402   score_ms=2681
query B scored=13108993 bound_pruned=961574   score_ms=1970
query C scored=12606815 bound_pruned=1463752  score_ms=1835
```

The skip rate was only about 1.6% to 10.4%, while the byte-overlap bound had to
scan every fuzzy candidate that reached this stage. The reduced RapidFuzz calls
did not pay for the extra Rust-side scan. This implementation was reverted.

The conclusion is that naive byte-overlap is a safe but too-loose bound for this
data. Frequent bytes in the Hangul-disassembled representation make overlap
easy to satisfy even when the candidate cannot realistically rank well. A useful
lossless pruning layer needs a tighter and cheaper representation, such as
q-gram or segment-aware filtering, preferably with precomputed per-message
metadata.

### Segment filter dry run

Tried a dry-run segment filter based on the PASS-JOIN-style pigeonhole idea:
derive a maximum allowed Indel distance from the final top-k cutoff, split the
query into `max_distance + 1` exact segments, and count how many fuzzy
candidates would contain at least one segment. Results were not used to filter;
the run only measured candidate selectivity and retained-result misses.

Representative server result:

```text
query C converted_len=18 take=500
cutoff=72.222 max_dist=10 segments=11 min_segment_len=1
fuzzy_checked=14070566 segment_candidates=13944253
retained_checked=499 retained_missed=0
segment_candidate_ratio=0.991023 segment_ms=3502.992
```

This was not useful. The final cutoff was only about `72`, so the lossless
distance bound allowed `10` edits for an 18-byte converted query. Splitting into
`11` segments forced `min_segment_len=1`, which makes the candidate condition
almost meaningless: about 99.1% of fuzzy candidates still passed. The dry-run
itself added about 3.5 seconds because it rescanned candidates without an index.

Raising the minimum segment length manually, for example to `3`, would likely
reduce candidates but would no longer be a proven lossless filter at this
cutoff. A lossless segment filter only looks promising when the top-k cutoff is
high enough that segments remain selective naturally, roughly when segment
lengths stay above the very common 1-2 byte range.

## Remaining Headroom

The current full-search bottleneck is mostly the number of fuzzy candidates. The
big future wins are probably structural rather than micro-optimizations.

Most promising options:

- `3-gram` or similar inverted index: high possible impact, high memory and
  implementation risk.
- length-sorted candidate storage: lower risk, may reduce full-scan overhead but
  probably not the main `score_ms` cost.
- more compact message storage: already yielded a lower-allocation layout by
  using contiguous messages and per-article indexes. Further reductions would
  require a larger packed-string arena or on-disk format change.
- byte/char multiset upper-bound prefilter: lossless in principle, but the
  naive on-the-fly byte-overlap version was too loose and too expensive. It
  should only be revisited with compact precomputed message metadata and better
  selectivity.
- thread-local scratch reuse: low semantic risk, but the measured impact was
  unclear and a local implementation duplicated RapidFuzz internals, so it is
  not worth keeping unless future allocator profiling shows a real allocation
  bottleneck.
- segment filter-and-verify: lossless in principle, but the measured low-cutoff
  case produced 1-byte segments and a 99% candidate ratio. It should not be
  pursued for broad `contains` unless future profiling shows much higher
  cutoffs and naturally selective segments.

If optimization work resumes later, start from explicit counters such as:

```text
prefilter_checked
prefilter_would_skip
prefilter_ms
rapidfuzz_calls
```

Do not enable a candidate prefilter permanently unless server logs show that its
skip rate is high enough to pay for its own memory and CPU cost. As of the
experiments above, the remaining safe wins are not obvious; further work likely
requires either deeper RapidFuzz internals work or a larger indexed search
design.
