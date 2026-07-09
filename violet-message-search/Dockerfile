FROM rust:1.85-bookworm AS builder

RUN apt-get update \
  && apt-get install -y --no-install-recommends clang cmake ninja-build pkg-config \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /src

COPY . .

RUN cargo build --release --features raw --bin fast-search-rs

FROM debian:bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates libstdc++6 \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /src/target/release/fast-search-rs /usr/local/bin/fast-search-rs

EXPOSE 12332

ENTRYPOINT ["fast-search-rs"]
CMD ["0.0.0.0", "12332", "--data-paths", "/data/merged-0.fscm"]
