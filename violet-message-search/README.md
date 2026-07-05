# Fast Search for Comic Message

## How to run?

```sh
cargo run -r --bin raw-compress -- --raw-dir ../violet-ocr/raw --output-dir data
cargo run -r --bin fast-search-rs -- 127.0.0.1 12332 --data-paths data/merged-0.fscm
```

Use `--splits N` only when you want to generate multiple `.fscm` files.
