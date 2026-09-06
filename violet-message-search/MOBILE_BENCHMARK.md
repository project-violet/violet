# Y700 full-corpus mobile scan — 2026-09-06

## Further tuning

Validating a contiguous text block once and checking individual UTF-8 boundaries
replaces per-message UTF-8 validation. Invalid bytes in unused gaps retain a
per-record fallback; malformed message text and split character boundaries are
still rejected. No index, extra allocation, or ranking approximation is added.

On the same full corpus, four threads and limit 50, three sequential rounds:

| Query | Previous 512 MiB budget | Block validation, 512 MiB budget |
|---|---:|---:|
| Word contains | 3.417 s | 3.075 s |
| Sentence contains | 5.779 s | 5.537 s |
| Random contains | 5.706 s | 5.412 s |
| Sentence similar | 3.477 s | 3.072 s |

Values are medians. Peak sampled RSS remains 167.9 MiB. These sequential trials
suggest a modest 4–12% reduction; they are not controlled thermal/cold-cache trials.
All 12 top-50 score/correctness sequences matched the previous version, all
queries scanned 45,548,502 records, and admission/cancellation checks passed.
Raw and non-raw builds each pass 39 tests, including malformed UTF-8 boundaries
and valid messages separated by an invalid unused gap.

Smaller-budget probes using the previous binary (two rounds each):

| Allocation budget | Peak sampled RSS | Word | Sentence | Random | Similar |
|---|---:|---:|---:|---:|---:|
| 256 MiB | 88.7 MiB | 3.612 s | 5.940 s | 5.833 s | 3.538 s |
| 128 MiB | 75.6 MiB | 3.494 s | 6.286 s | 6.034 s | 3.519 s |

Both probes retained identical score/correctness sequences and full scans.
128 MiB saved only another 13 MiB RSS while making sentence/random scans slower.
The allocation budget is not a hard RSS or total Android memory cap; OS file
cache and other processes remain separate. Benchmark files are named
`mobile-utf8-results.json`, `mobile-budget256-results.json`, and
`mobile-budget128-results.json` in the existing tablet benchmark directory.

The new binary was also tested at 256 MiB (two rounds,
`mobile-utf8-256-results.json`): median word/sentence/random/similar times were
3.220 / 5.937 / 5.963 / 3.135 seconds, with 88.6 MiB peak RSS. All eight score
sequences, full-scan counters, and admission/cancellation checks passed. Choose
256 MiB to save about 79 MiB RSS at a roughly 0.4–0.6 second sentence/random cost
in this sample. The launcher retains 512 MiB for speed, already well below the
requested 500 MiB–1 GiB process-memory target. Its binary includes block validation.

## Optimized implementation

The current implementation scans each block once, performs exact/fuzzy work in
that block, and overlaps the next block's reading/decoding with scoring. Two
owned buffers are recycled over bounded channels, without copying or queuing
blocks. It retains full-corpus top-k ranking and advisory file-cache release.

Measured on the same complete tablet dataset below, with violet-web running,
512 MiB allocation budget, four scoring threads, and 50 results per query.
Three sequential rounds per executable; table values are **medians**:

| Query | Initial mobile | Optimized mobile | Time reduction |
|---|---:|---:|---:|
| contains: 괜찮아 | 5.251 s | **3.417 s** | 34.9% |
| contains: 오늘은 날씨가 정말 좋은 것 같아 | 13.663 s | **5.779 s** | 57.7% |
| contains: 쀼걀뭉쟈켑 댜퐁쥬릅 뀨헙쨍 | 13.749 s | **5.706 s** | 58.5% |
| similar: 오늘은 날씨가 정말 좋은 것 같아 | 5.408 s | **3.477 s** | 35.7% |

Before/after samples, in seconds:

- Word: `[5.511, 5.180, 5.251]` → `[3.456, 3.417, 3.235]`.
- Sentence: `[13.840, 13.559, 13.663]` → `[5.646, 5.779, 5.951]`.
- Random: `[13.924, 13.749, 13.618]` → `[5.591, 5.774, 5.706]`.
- Similar: `[5.435, 5.306, 5.408]` → `[3.630, 3.477, 3.247]`.

Peak sampled FSCM RSS increased from **87.2 to 167.9 MiB**, below the 512 MiB
test-watchdog threshold. Minimum system MemAvailable was **6253.3 MiB**. Neither
memory watchdog triggered. These are process RSS observations, not a device-wide
hard memory limit. Results are a small sequential benchmark, not randomized
trials or a sustained thermal characterization.

All 12 optimized responses matched the initial executable's sorted top-50
`(MatchScore, Correctness)` pairs. Every optimized query reported exactly
45,548,502 completed records (one pass). Busy admission returned 503 and cancelled
search returned 409 in both versions. Equal-score/equal-correctness identities
remain unspecified. The optimized raw and non-raw builds each pass 38 Rust tests,
including empty text/query, multiple files, tiny block boundaries, and reader
shutdown on mid-scan cancellation or consumer failure.

A large metadata-batch experiment used about 45 MiB more RAM without a clear
speed improvement and was removed. Six scoring threads did not provide a clear
overall gain over four, so the default remains four. No approximate candidate
filter, extra index file, or corpus reduction was introduced.

Raw results remain on the tablet in `~/codex-work/fscm-bench-20260906/` as
`mobile-baseline3-results.json` and `mobile-final3-results.json`. The current
`start-mobile.sh` uses the optimized executable. Test processes were stopped.
For phase diagnostics, set `FSCM_PROFILE=1`; reader and scoring times overlap and
must not be added to infer wall time.

## Initial implementation (historical baseline)

Measured inside the existing `violet-message-search` Debian proot container on
TB320FC / SM8475 (Snapdragon 8+ Gen 1), Android 14, approximately 12 GB RAM.
The existing violet-web Node process remained running throughout.

Unlike the earlier 1/16 sample experiment, this test used the complete file
already on the tablet: **3,100,638,543 bytes / 45,548,502 messages**. The PC's newer
file has 46,307,303 messages; these are not identical datasets.

Configuration: `--mobile --memory-budget-mb 512 --search-threads 4`, raw-enabled
ARM64 GNU/Linux release executable built with `Dockerfile.mobile-build`.
Requests ran sequentially over loopback with `limit=50`; mobile result caching
was disabled. Each query was measured once, including reading from storage.

| Mode | Query | HTTP response time |
|---|---|---:|
| contains | 괜찮아 | 6.128 s |
| contains | 오늘은 날씨가 정말 좋은 것 같아 | 14.020 s |
| contains | 쀼걀뭉쟈켑 댜퐁쥬릅 뀨헙쨍 | 13.840 s |
| similar | 오늘은 날씨가 정말 좋은 것 같아 | 5.358 s |

All requests returned 50 results. Progress reported 45,548,502 records scanned
for the exact-filled word query and similar search, and 91,097,004 (two complete
passes) for the sentence/random contains searches.

- Peak sampled FSCM RSS: **87.2 MiB** (approximately 100 ms sampling).
- Minimum device `MemAvailable`: **6359.9 MiB**.
- The external test watchdog (900 MiB FSCM RSS / 1 GiB available memory) did not
  trigger. This watchdog was part of the test harness, not the shipped server.
- Concurrent search returned **503**. Cancellation was accepted and the active
  search returned **409**, without partial results.
- The test server was stopped afterwards; the existing web process remained.

RSS excludes proot overhead and the shared OS file cache. `MemAvailable` includes
kernel estimates of reclaimable memory. These observations are not hard memory
limits, peak PSS measurements, cold-cache guarantees, or sustained thermal tests.

### Initial correctness and regression checks

37 Rust tests passed with raw enabled, and 37 without raw. New tests force small
block boundaries and multiple files, comparing resident and mobile results for
contains/similar, exact-first/fuzzy fallback, article/range/multiple/empty scopes,
and raw result text. They also cover truncated/oversized inputs, bounded buffers,
global record offsets, concurrent admission and cancellation reset.

A Windows release mobile server also scanned the entire newer PC corpus. For the
same four queries, the top-50 `(MatchScore, Correctness)` sequences matched the
existing resident Docker server. Equal-score/equal-correctness ties do not promise
identical message identities. HTTP admission/cancellation were verified there as
well. PC timings are not used to infer Y700 throughput.

### Initial assessment

The full corpus is searchable without corpus-sized resident allocations. Current
latency is **5–14 seconds in this small query set**, not subsecond. A disk search
index or a separate compact search layout is still needed for interactive speed;
the implementation deliberately retains full-corpus ranking instead of silently
limiting search candidates.

The executable and a foreground launcher are retained on the tablet under
`~/codex-work/fscm-bench-20260906/`. Raw measurements and the guarded Python harness
are retained there as `mobile-y700-results.json` and `mobile-bench.py`.
