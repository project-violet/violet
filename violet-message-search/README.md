# Fast Search for Comic Message

## How to run?

```sh
cargo run -r --bin raw-compress -- --raw-dir ../violet-ocr/raw --output-dir data
cargo run -r --bin fast-search-rs -- 127.0.0.1 12332 --data-paths data/merged-0.fscm
```

Use `--splits N` only when you want to generate multiple `.fscm` files.

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
