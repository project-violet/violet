# Fast Search for Comic Message

## How to run?

```sh
cargo run -r --features raw -- 127.0.0.1 12332 --data-paths merged-0.json merged-1.json merged-2.json
```

For faster startup with lower peak memory, generate and load the flat binary
format:

```sh
cargo run -r --bin raw-compress -- --raw-dir ../violet-ocr/raw --output-dir data --splits 3 --format fscm
cargo run -r --bin fast-search-rs -- 127.0.0.1 12332 --data-paths data/merged-0.fscm data/merged-1.fscm data/merged-2.fscm
```
