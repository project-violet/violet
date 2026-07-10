# Docker Boot Stack

This Compose stack mirrors `boot.cmd` with separate containers for each process:

- `hsync`: runs `fast-hsync` at startup and one hour after each completed run.
- `message-search`: Rust `fast-search-rs` server on port `12332`.
- `graph`: Go `violet-graph serve` server on port `8787`.
- `web`: production `violet-web` backend and frontend on port `3001`.

Large data files are mounted from one data root instead of copied into images.

## Data Inputs

The default data root is `./data`. Override it by copying `.env.docker.example` to `.env` and setting `VIOLET_DATA_ROOT`.

Expected layout:

```text
data/
  data.db
  user.db
  merged-0.fscm
  graph.csv
```

For an external folder, use a path such as:

```env
VIOLET_DATA_ROOT=D:/violet-data
```

All four data files go directly in that folder. No service-specific subdirectories are used.

## Run

```sh
docker compose up --build
```

`hsync` starts with the rest of the stack. It runs immediately, waits 3600
seconds after the process exits, and then runs again. Override the interval in
`.env` when needed. The scheduled service enables quiet mode, so Docker logs
keep phase summaries and errors without one progress update per request:

```env
HSYNC_INTERVAL_SECONDS=3600
```

Run a separate one-shot sync without starting the scheduler:

```sh
docker compose run --rm --no-deps --entrypoint fast-hsync hsync /data/data.db
```

### Database concurrency

`fast-hsync` and `violet-web` both use SQLite WAL mode. The web backend keeps
a read-only connection to `data.db`, while `fast-hsync` commits writes in
transactions, so web requests can continue while synchronization is running.
Only one `fast-hsync` process should write the database at a time.

Content rows and FTS updates become visible after their transactions commit.
The in-memory suggestion cache is not rebuilt automatically, so newly added
suggestions require a web restart or a manual suggestion-cache rebuild.

## Multi-Arch Builds

The Dockerfiles use official multi-arch base images and avoid checked-in Windows `.exe` files. Build locally for the current machine with:

```sh
docker compose build
```

Build and push both `linux/amd64` and `linux/arm64` images with Buildx:

```sh
docker buildx build --platform linux/amd64,linux/arm64 -t your-registry/violet-fast-hsync:latest --push ./fast-hsync
docker buildx build --platform linux/amd64,linux/arm64 -t your-registry/violet-message-search:latest --push ./violet-message-search
docker buildx build --platform linux/amd64,linux/arm64 -t your-registry/violet-graph:latest --push ./violet-graph
docker buildx build --platform linux/amd64,linux/arm64 -t your-registry/violet-web:latest --push ./violet-web
```

The Rust image is the most likely place to fail cross-architecture builds because it compiles a C++ binding through `bindgen`, `cmake`, and `ninja`. The Dockerfile installs those tools in the builder image so both amd64 and arm64 builds use the same Linux build path.
