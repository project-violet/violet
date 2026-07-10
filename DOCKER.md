# Docker Boot Stack

This Compose stack mirrors `boot.cmd` with separate containers for each process:

- `hsync`: one-shot `fast-hsync` database sync job.
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
docker compose up --build web message-search graph
```

Run the sync job only when you want to update the backend database:

```sh
docker compose --profile sync run --rm hsync
```

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
