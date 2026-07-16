# violet-llm

Qwen3-Embedding-4B experiment over the latest 5,000 numeric files in
`../violet-ocr/raw-merged-v2`.

    cd violet-llm
    python -m venv .venv
    .\.venv\Scripts\Activate.ps1
    # Install CUDA PyTorch appropriate for this PC first.
    python -m pip install -r requirements.txt

    # Prepare latest three works first.
    python prepare.py --work-count 3 --dataset-name smoke-3 --overwrite
    python embed.py --dataset-name smoke-3 --output-name smoke-3 --batch-size 2

    # Full latest 5,000.
    python prepare.py
    python embed.py

    python search.py "your Korean scene query" --top-k 20

The default chunk is a three-page window with a two-page stride. Each stored
chunk retains the source page, dialogue index, confidence, and bbox.

Performance defaults use CUDA FP16, SDPA, TF32 settings, length bucketing,
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
