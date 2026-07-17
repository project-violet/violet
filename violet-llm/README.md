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

Search uses two quantized Qwen3 4B models by default: the official
`Qwen3-Embedding-4B-GGUF` Q5_K_M model for the query and a
`Voodisss/Qwen3-Reranker-4B-GGUF-llama_cpp` Q4_K_M model for reranking. This
conversion includes Qwen's yes/no classifier, rank pooling metadata, and the
reranking chat template; generic Qwen3 GGUF conversions do not. Install a current
CUDA-enabled llama.cpp build, start both local servers, then search:

    python search.py "your Korean scene query" --top-k 20

Use a CUDA-enabled llama.cpp build. The winget package currently installs the
Vulkan build, which can fail with `vk::Queue::submit: ErrorDeviceLost` under
this two-model workload. Put the official CUDA build in
`.tools/llama-cuda`; `search.py` prefers it over PATH. `search.py` starts both
local servers automatically when needed. Manual server
startup remains available for inspecting logs or warming the models first:

    .\start-quantized.ps1

The embedding search retrieves 100 candidates by default and the reranker
returns the final 20. Increase the candidate pool independently when needed:

    python search.py "your Korean scene query" --candidate-k 200 --top-k 20

Use `--no-rerank` to inspect the quantized embedding ranking alone. Stop both
background servers when finished:

    .\stop-quantized.ps1

The first server startup downloads roughly 5.4 GB of model files. Runtime logs
and process IDs are kept under the ignored `.runtime` directory. The endpoints
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

    $env:PYTHONUTF8="1"
    python3 -m modal run embed-modal.py --work-count 5000
    python3 -m modal run embed-modal.py --work-count 10000

`--work-count` means new works, not the final total. With 10,000 works already
complete, the first command processes works 10,001 through 15,000. Results are
downloaded, validated, and merged into the existing `latest-5000` output one
work directory at a time. Temporary Modal inputs and result archives are removed
after a successful merge; pass `--keep-remote` to retain them.
