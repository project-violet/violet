FROM --platform=$BUILDPLATFORM golang:1.25-bookworm AS builder

ARG TARGETOS
ARG TARGETARCH

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags="-s -w" -o /out/fast-hsync .

FROM debian:bookworm-slim

WORKDIR /data

COPY --from=builder /out/fast-hsync /usr/local/bin/fast-hsync

ENTRYPOINT ["fast-hsync"]
CMD ["/data/data.db"]
