# violet-llm

Qwen3-Embedding-4B experiment over the latest 10,000 numeric files in
`../violet-ocr/raw-merged-v2`.

    cd violet-llm
    python -m venv .venv
    .\.venv\Scripts\Activate.ps1
    # Install CUDA PyTorch appropriate for this PC first.
    python -m pip install -r requirements.txt

    # Prepare latest three works first.
    python prepare.py --work-count 3 --dataset-name smoke-3 --overwrite
    python embed.py --dataset-name smoke-3 --output-name smoke-3 --batch-size 2

    # Expand the existing latest-5000 dataset to the latest 10,000 works.
    # The output name stays latest-5000 so the completed first 5,000 are reused.
    python prepare.py --overwrite
    python embed.py

Search uses the quantized `Qwen3-Embedding-4B-GGUF` Q5_K_M model through
llama.cpp for the query and the official BF16 `Qwen3-Reranker-0.6B` through
vLLM for reranking. Both model servers run as CUDA-enabled Docker Compose
services. Start them from the repository root, then search:

    docker compose up -d embedding-llama reranker-vllm
    cd violet-llm
    python search.py "your Korean scene query" --top-k 20

The embedding service uses the official llama.cpp `server-cuda` image and keeps
downloaded GGUF files in the `violet-llama-cache` Docker volume. The reranker
keeps Hugging Face model files in `violet-huggingface-cache`. Inspect startup
and model-loading logs with:

    docker compose logs -f embedding-llama reranker-vllm

`search.py` only checks that the configured endpoints are ready; service
lifecycle is owned entirely by Docker Compose.

The embedding search retrieves 100 candidates by default and the reranker
returns the final 20. Increase the candidate pool independently when needed:

    python search.py "your Korean scene query" --candidate-k 200 --top-k 20

After adding or embedding works, build the consolidated search index once:

    python build_index.py --output-name latest-5000

The builder combines the per-work float16 arrays into 100,000-vector binary
shards and writes one compact location map. Eight reader threads prefetch the
many small source files by default, while tqdm reports works, vectors, and
completed shards. Tune the readers or rebuild an existing index when needed:

    python build_index.py --workers 8 --shard-rows 100000 --overwrite

Search automatically uses the consolidated index when its manifest exists.
Only the final candidate works have their chunks JSON parsed; without an index,
search falls back to the legacy per-work scan and prints the build command.
The index is derived entirely from existing embeddings, so building it does not
load the embedding model or require a GPU. Rebuild it after adding more works.

    python search.py "your Korean scene query" --candidate-k 300 --top-k 100

Use `--no-rerank` to inspect the quantized embedding ranking alone. Stop the
model services when finished:

    docker compose stop embedding-llama reranker-vllm

The first startup downloads the model files and the vLLM CUDA image. Runtime
logs and process IDs are kept under the ignored `.runtime` directory. The endpoints
can also be supplied through `--embedding-url`, `--reranker-url`,
`VIOLET_EMBEDDING_URL`, and `VIOLET_RERANKER_URL`.

Existing indexes remain usable: their document vectors were created with the
same Qwen3-Embedding-4B vector space. The quantized query vector is truncated
to the index's configured Matryoshka dimension and normalized before cosine
search. Compare `--no-rerank` results against the prior FP16 query path before
rebuilding a large index if exact rank stability matters.

The default chunk is a three-page window with a two-page stride. Each stored
chunk retains the source page, dialogue index, confidence, and bbox.

Offline index construction in `embed.py` continues to use CUDA FP16 because
that path already has high-throughput token-budget batching. Performance
defaults use CUDA FP16, SDPA, TF32 settings, length bucketing,
inference mode, and automatic CUDA OOM backoff. Tokenization results are reused
directly by the model forward pass, and a background worker prepares the next
work buffer while the GPU processes the current one. Up to 16 works are
buffered together, then batches are filled by padded-token cost rather than a
fixed request count. The defaults allow 2,048 padded tokens and 64 requests per
GPU batch:

    python embed.py --max-batch-tokens 2048 --batch-size 64 --work-buffer-size 16

These defaults work on native Windows. Optional backends can be tested on a
small dataset first:

    python embed.py --dataset-name smoke-3 --output-name flash-smoke --attention flash_attention_2
    python embed.py --dataset-name smoke-3 --output-name compile-smoke --compile

If the `flash_attn` extension is unavailable, Flash Attention automatically
falls back to SDPA. If TorchInductor/Triton is unavailable, `--compile`
automatically falls back to eager CUDA. Native Windows commonly uses the
default SDPA path; WSL2/Linux is the practical route for testing FlashAttention
2. The progress bar reports end-to-end input `tok_s` and the effective batch
size.

On an RTX 4070 Ti SUPER, a 20-work/142,371-token benchmark measured about
7,378 input tok/s with pretokenized token-budget batches versus 5,661 input
tok/s with work-local fixed batches of 12 (about 30% faster). This is an
end-to-end embedding-loop measurement and excludes model loading. The progress
bar also reports GPU-only input throughput and the padding overhead.

Backend experiments on the same 20-work dataset measured PyTorch SDPA `auto`
at about 7,332 input tok/s, forced `math` at 5,805 tok/s, and forced `cudnn`
at 2,801 tok/s. Native Windows PyTorch had no compiled FlashAttention kernel,
and its memory-efficient kernel could not handle Qwen3's grouped-query head
layout. Keep `--sdpa-backend auto` unless a later PyTorch build changes this.

`benchmark_tei.py` benchmarks a running Hugging Face TEI endpoint and compares
its embeddings with a local output. TEI 1.9's Ada image required the WSL CUDA
driver library to be preloaded on this PC before it selected FlashQwen3:

    docker run --gpus all -e LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libcuda.so.1 `
      -e LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/usr/local/cuda/lib64 `
      -p 8080:80 -v "$env:USERPROFILE\.cache\huggingface\hub:/data:ro" `
      ghcr.io/huggingface/text-embeddings-inference:89-1.9 `
      --model-id Qwen/Qwen3-Embedding-4B --dtype float16 --max-batch-tokens 2048

    python benchmark_tei.py --concurrency 1 --reference-output benchmark-20-pretokenized

Sequential TEI measured about 4,584 input tok/s, so the optimized local
PyTorch path remains the default.
## Incremental Modal embedding

`embed-modal.py` runs only embedding on Modal and keeps search local. It scans
`outputs/Qwen--Qwen3-Embedding-4B/latest-5000/works`, excludes every work with
a completed `metadata.json`, then prepares and uploads the requested number of
newest unfinished works. H100 is the default GPU.

    .\run-modal.ps1 -WorkCount 5000
    .\run-modal.ps1 -WorkCount 10000

The wrapper keeps the console output visible and saves the complete local and
streamed Modal output under `.runtime/modal-YYYYMMDD-HHMMSS.log`. The remote
embedding subprocess also writes `remote.log`; after a successful result
download it is retained as `.runtime/modal-RUN_ID.remote.log`. Modal keeps the
same remote output in the App Logs view for failed or interrupted runs.

`--work-count` means new works, not the final total. With 10,000 works already
complete, the first command processes works 10,001 through 15,000. Results are
downloaded, validated, and merged into the existing `latest-5000` output one
work directory at a time. Temporary Modal inputs and result archives are removed
after a successful merge; pass `--keep-remote` to retain them.

## Search API

`server.py` exposes the consolidated embedding index over HTTP. By default it
uses a FAISS SQ8 exhaustive index and compact random-access metadata. Build
these artifacts after each `build_index.py` run:

    pip install -r requirements-benchmark.txt
    python benchmark_search_index.py build --kind sq8 --overwrite
    python benchmark_search_index.py build-metadata --overwrite

Run an isolated A/B benchmark without invoking the reranker:

    python benchmark_search_index.py bench --candidate-k 500 `
      --report .runtime/search-index-benchmark.json

On the current 2,537,826-vector index, the ten-query test measured a 6.43s
median for the FP16 scan versus 0.245s for SQ8, with 99.34% mean Recall@500.
Compact metadata lookup took 0.003s versus 1.22s for per-work JSON files.
Set `VIOLET_LLM_ACCELERATED_INDEX=false` to A/B test or immediately roll back
to the exact FP16 scan. `VIOLET_LLM_FAISS_THREADS` controls FAISS CPU threads.

Start both model servers and the search API from the repository root:

    docker compose up -d --build embedding-llama reranker-vllm llm-search

The search container listens on port `8788` and calls both model services
through the Compose network. For local CLI and diagnostics, the embedding API
is exposed on port `8081` and vLLM on the original reranker port `8082`. The
default output mount is
`./violet-llm/outputs:/data:ro`; override `VIOLET_LLM_OUTPUT_ROOT` or
`VIOLET_LLM_OUTPUT_NAME` when necessary.

    Invoke-RestMethod http://127.0.0.1:8788/health

    $body = @{
      query = "검색어"
      candidate_k = 500
      top_k = 10
      rerank = $true
      include_messages = $false
    } | ConvertTo-Json
    Invoke-RestMethod -Method Post `
      -Uri http://127.0.0.1:8788/v1/search `
      -ContentType "application/json; charset=utf-8" `
      -Body ([Text.Encoding]::UTF8.GetBytes($body))

Results contain `rank`, `rerank_score`, `embed_score`, `work`, and `pages`.
Set `include_messages` to `true` to add `messages`. Reranking still reads the
candidate dialogue internally even when messages are omitted from the response.
Set `rerank` to `false` for embedding-only ranking. The first search after a
container start can be slower while Docker Desktop warms the read-only index
pages; subsequent searches use the OS page cache.
