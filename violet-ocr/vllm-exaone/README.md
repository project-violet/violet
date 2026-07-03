# EXAONE 3.5 7.8B AWQ on vLLM

This folder contains the WSL2 vLLM setup notes and helper scripts for running
`LGAI-EXAONE/EXAONE-3.5-7.8B-Instruct-AWQ` as an OpenAI-compatible local API.

## Current Setup

- WSL distro: `Ubuntu-24.04`
- Python venv: `/root/vllm-venv`
- vLLM: `0.23.0`
- Model: `LGAI-EXAONE/EXAONE-3.5-7.8B-Instruct-AWQ`
- Served model name: `exaone3.5:7.8b-awq`
- API base URL: `http://localhost:8001/v1`
- GPU memory observed: about `15.7 GiB / 16.4 GiB`

The server uses `--trust-remote-code` because the EXAONE Hugging Face repository
requires custom model code.

## Why FlashInfer Sampler Is Disabled

On this WSL2 environment, vLLM loaded the EXAONE AWQ model successfully, but
FlashInfer top-k/top-p sampler JIT failed with CUDA toolkit header mismatch.

The server therefore sets:

```bash
VLLM_USE_FLASHINFER_SAMPLER=0
```

This keeps vLLM running by falling back to the native PyTorch sampler. AWQ Marlin,
FlashAttention, and CUDA graph capture still initialize.

## Start

From Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\violet-ocr\vllm-exaone\start.ps1
```

Or:

```powershell
powershell -ExecutionPolicy Bypass -File .\violet-ocr\vllm-exaone\start.ps1
```

The PowerShell helper resolves the script path from its own folder, so it does
not depend on the old `violet-project/violet-search` checkout path.

## Double-Click Control Menu

Run this file from Explorer:

```text
vllm-exaone-control.cmd
```

It opens a console menu for:

- start
- stop
- restart
- status
- watch metrics
- test chat
- tail log

## Stop

```powershell
powershell -ExecutionPolicy Bypass -File .\violet-ocr\vllm-exaone\stop.ps1
```

Or:

```powershell
powershell -ExecutionPolicy Bypass -File .\violet-ocr\vllm-exaone\stop.ps1
```

## Status

```powershell
powershell -ExecutionPolicy Bypass -File .\violet-ocr\vllm-exaone\status.ps1
```

Checks:

- WSL process list
- `GET http://localhost:8001/v1/models`
- NVIDIA VRAM usage

## Watch Metrics

Use this while OCR correction is running in another terminal:

```powershell
powershell -ExecutionPolicy Bypass -File .\violet-ocr\vllm-exaone\watch_metrics.ps1
```

Default interval is 5 seconds. For a 1-second refresh:

```powershell
powershell -ExecutionPolicy Bypass -File .\violet-ocr\vllm-exaone\watch_metrics.ps1 -IntervalSeconds 1
```

Run a fixed number of samples:

```powershell
powershell -ExecutionPolicy Bypass -File .\violet-ocr\vllm-exaone\watch_metrics.ps1 -IntervalSeconds 1 -Samples 10
```

Columns:

- `out_tok/s`: output token throughput from `vllm:generation_tokens_total`
- `in_tok/s`: input/prompt token throughput from `vllm:prompt_tokens_total`
- `total_tok/s`: input plus output token throughput
- `running`: active requests currently executing
- `waiting`: queued requests waiting for scheduler capacity
- `kv_cache%`: current KV cache usage percentage

## Test Chat

```powershell
powershell -ExecutionPolicy Bypass -File .\violet-ocr\vllm-exaone\test_chat.ps1
```

Equivalent API call:

```http
POST http://localhost:8001/v1/chat/completions
Content-Type: application/json
```

```json
{
  "model": "exaone3.5:7.8b-awq",
  "messages": [
    {
      "role": "user",
      "content": "한국어로 한 문장만 답해줘. OCR 교정 테스트야."
    }
  ],
  "temperature": 0,
  "max_tokens": 64
}
```

## Notes

- This is not the same artifact as Ollama's `exaone3.5:7.8b` GGUF model.
- Ollama uses a GGUF/llama.cpp-style runtime.
- This vLLM setup uses the Hugging Face AWQ model.
- The OpenAI-compatible endpoint can be used from Python via `/v1/chat/completions`.
