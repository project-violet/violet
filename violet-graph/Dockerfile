FROM --platform=$BUILDPLATFORM golang:1.25-bookworm AS builder

ARG TARGETOS
ARG TARGETARCH

WORKDIR /src

COPY go.mod ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags="-s -w" -o /out/violet-graph .

FROM debian:bookworm-slim

WORKDIR /app

COPY --from=builder /out/violet-graph /usr/local/bin/violet-graph

EXPOSE 8787

ENTRYPOINT ["violet-graph"]
CMD ["serve", "--host", "0.0.0.0", "--input", "/data/graph.csv", "--port", "8787"]
