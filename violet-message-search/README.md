# Fast Search for Comic Message

## How to run?

```sh
cargo run -r --bin raw-compress -- --raw-dir ../violet-ocr/raw --output-dir data
cargo run -r --bin fast-search-rs -- 127.0.0.1 12332 --data-paths data/merged-0.fscm
```

Use `--splits N` only when you want to generate multiple `.fscm` files.

## Mobile / bounded-memory full-corpus search

```sh
fast-search-rs 127.0.0.1 12332 --mobile --memory-budget-mb 512 --search-threads 4 \
  --data-paths /data/merged-0.fscm
```

This scans **all records** in existing FSCM files, without loading the corpus or
the per-article message index into RAM. No conversion or reduced dataset is
required. Desktop startup and caching remain the default without `--mobile`.

`--memory-budget-mb` accepts 128–1024 MiB (default 512). It sizes bounded internal
allocations; it is **not an OS-enforced RSS/PSS or device-wide memory limit**.
On the measured Y700 full corpus, 512 MiB used about 168 MiB process RSS;
256 MiB used about 89 MiB, with sentence/random searches roughly 0.4–0.6 seconds
slower. See [MOBILE_BENCHMARK.md](MOBILE_BENCHMARK.md) for measurements and limits.
Each record buffer uses at most one eighth of the budget and 1,048,576 records;
each text buffer uses at most one eighth and 32 MiB. Two blocks are reused: one
is scored while a reader thread fills the other. A bounded handoff transfers
ownership without copying blocks or accumulating a queue. Only top-k indices are kept;
raw text is fetched for final results. Linux/Android receives advisory file-cache
release requests after each processed block. The OS can ignore these requests.
Allocator/runtime overhead and shared OS file cache must be measured separately.

Mobile mode disables the unbounded result cache and admits one data operation at
a time. Concurrent search, article, or list requests receive HTTP **503** instead
of accumulating work. `--search-threads` accepts 1–8 (default 4).

The existing contains/similar, article, multi-article and ID-range APIs work with
mobile storage. Score and correctness ordering is preserved; equal-score,
equal-correctness ties may select different messages, as with parallel desktop
search. `contains` checks exact matches and performs any required fuzzy scoring
within each block, so it reads the corpus only once. Once the global top-k is
filled with exact matches, subsequent blocks skip fuzzy scoring. Earlier fuzzy
results are evicted by later exact matches. All scopes currently scan file metadata; there is no disk search
index yet, and full searches can take substantially longer than resident search.

Progress and cancellation are available directly from FSCM:

```sh
curl http://127.0.0.1:12332/mobile/status
curl -X POST http://127.0.0.1:12332/mobile/cancel
```

Status reports active/cancelled, scanned/planned records, total corpus records,
and the configured allocation budget. Scanned records count completed scoring
blocks, not reader prefetch. Cancellation is checked at block boundaries and during metadata
decoding; the interrupted search returns HTTP **409**, never a partial success.
These controls have not yet been integrated into the Violet Web UI. A disconnected
HTTP client does not automatically cancel its search. Set `FSCM_TIMEOUT_MS` on the
web backend above the observed full-search latency (default there is 30 seconds).

Queries are capped at 4096 UTF-8 bytes. Mobile article responses are capped at
10,000 records, raw response bytes at one sixteenth of the budget, and article ID
list cardinality is bounded. Oversized records/responses or corrupt files fail
explicitly rather than growing buffers without limit. Keep FSCM files immutable
while the server is running.

To cross-compile a Debian ARM64/proot executable on an x86-64 Docker host:

```sh
docker build -f Dockerfile.mobile-build --output type=local,dest=./mobile-dist .
```

The resulting `mobile-dist/fast-search-rs-mobile` requires Debian-compatible
glibc and libstdc++; run it inside proot, not directly in the Android shell.

## Article ID range search

`/contains/:query` and `/similar/:query` accept inclusive `id_min` and
`id_max` query parameters. Either bound can be omitted. Invalid or reversed
bounds return HTTP 400; a range with no indexed works returns an empty array.
The range is applied before scoring and result limits, and is part of the cache key.

```text
http://localhost:22332/contains/hello?id_min=4031374&id_max=4170232&limit=100
```

`22332` is the host port in the local Docker Compose configuration; the service
still listens on `12332` inside the container. This feature does not require
rebuilding the `.fscm` data file.

Violet Web accepts `from`/`to` (inclusive `YYYY-MM-DD`) and `idMin`/`idMax`
on `/api/message-search`. It converts the publication dates in the content DB
to a minimum/maximum Hitomi ID and intersects this with any explicit ID bounds.
This is an ID envelope: publication dates do not always follow ID order, so it
is not a strict per-result publication-date filter. No dated works produces
empty results, not an unrestricted search.
