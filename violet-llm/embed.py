from __future__ import annotations

import argparse
import os
import shutil
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from tqdm import tqdm

from common import load_json, read_jsonl, safe_model_name, write_json, write_jsonl


ROOT = Path(__file__).resolve().parent
DEFAULT_MODEL = "Qwen/Qwen3-Embedding-4B"


@dataclass
class PendingWork:
    work_id: int
    rows: list[dict[str, object]]
    encoded_inputs: dict[str, list[list[int]]]
    token_lengths: list[int]
    vectors: np.ndarray
    temporary_dir: Path
    final_dir: Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Embed prepared works with Qwen3-Embedding-4B.")
    parser.add_argument("--dataset-name", default="latest-5000")
    parser.add_argument("--output-name", default="latest-5000")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--batch-size", type=int, default=64, help="Maximum requests in one GPU batch.")
    parser.add_argument(
        "--max-batch-tokens",
        type=int,
        default=2048,
        help="Maximum padded tokens in one GPU batch.",
    )
    parser.add_argument("--work-buffer-size", type=int, default=16)
    parser.add_argument("--max-length", type=int, default=1024)
    parser.add_argument("--dimensions", type=int, default=1024)
    parser.add_argument("--storage-dtype", choices=("float16", "float32"), default="float16")
    parser.add_argument("--device")
    parser.add_argument(
        "--attention",
        choices=("auto", "sdpa", "flash_attention_2"),
        default="sdpa",
        help="Attention backend; flash_attention_2 requires a compatible install.",
    )
    parser.add_argument(
        "--sdpa-backend",
        choices=("auto", "flash", "cudnn", "efficient", "math"),
        default="auto",
        help="Force a PyTorch SDPA CUDA kernel for benchmarking.",
    )
    parser.add_argument("--compile", action="store_true", help="Enable torch.compile after smoke testing it.")
    parser.add_argument(
        "--compile-mode",
        choices=("default", "reduce-overhead", "max-autotune"),
        default="reduce-overhead",
    )
    parser.add_argument("--no-length-bucket", action="store_true")
    parser.add_argument("--overwrite-work", action="store_true")
    return parser.parse_args()


def configure_cuda(torch: object, device: str) -> None:
    if device == "cpu":
        return
    torch.backends.cuda.matmul.allow_tf32 = True
    torch.backends.cudnn.allow_tf32 = True
    torch.set_float32_matmul_precision("high")


def configure_sdpa(torch: object, device: str, backend: str) -> None:
    if device == "cpu" or backend == "auto":
        return
    torch.backends.cuda.enable_flash_sdp(backend == "flash")
    torch.backends.cuda.enable_mem_efficient_sdp(backend == "efficient")
    torch.backends.cuda.enable_math_sdp(backend == "math")
    if hasattr(torch.backends.cuda, "enable_cudnn_sdp"):
        torch.backends.cuda.enable_cudnn_sdp(backend == "cudnn")


def load_model(args: argparse.Namespace, device: str, torch: object) -> tuple[object, str]:
    from sentence_transformers import SentenceTransformer

    attention = args.attention
    model_kwargs = {"torch_dtype": torch.float16 if device != "cpu" else torch.float32}
    if attention != "auto":
        model_kwargs["attn_implementation"] = attention

    try:
        model = SentenceTransformer(
            args.model,
            device=device,
            model_kwargs=model_kwargs,
            processor_kwargs={"padding_side": "left"},
        )
    except ImportError as error:
        if attention != "flash_attention_2":
            raise
        print(f"FlashAttention 2 unavailable ({error}); falling back to SDPA.")
        attention = "sdpa"
        model_kwargs["attn_implementation"] = attention
        model = SentenceTransformer(
            args.model,
            device=device,
            model_kwargs=model_kwargs,
            processor_kwargs={"padding_side": "left"},
        )
    return model, attention


def encode_pre_tokenized_with_backoff(
    model: object,
    encoded_inputs: dict[str, list[list[int]]],
    batch_size: int,
    torch: object,
    eager_auto_model: object | None,
) -> tuple[np.ndarray, int, object | None, int, float]:
    current_batch_size = batch_size
    while True:
        try:
            vectors: list[np.ndarray] = []
            padded_token_count = 0
            forward_started_at = time.perf_counter()
            with torch.inference_mode():
                for start in range(0, len(encoded_inputs["input_ids"]), current_batch_size):
                    stop = start + current_batch_size
                    batch_inputs = {
                        key: values[start:stop]
                        for key, values in encoded_inputs.items()
                    }
                    padded_token_count += max(map(len, batch_inputs["input_ids"])) * len(
                        batch_inputs["input_ids"]
                    )
                    features = model.tokenizer.pad(batch_inputs, padding=True, return_tensors="pt")
                    features = {
                        key: value.to(model.device, non_blocking=True)
                        for key, value in features.items()
                    }
                    embedding = model.forward(features)["sentence_embedding"]
                    vectors.append(embedding.float().cpu().numpy())
            forward_seconds = time.perf_counter() - forward_started_at
            return (
                np.concatenate(vectors, axis=0),
                current_batch_size,
                eager_auto_model,
                padded_token_count,
                forward_seconds,
            )
        except torch.OutOfMemoryError:
            if current_batch_size == 1:
                raise
            current_batch_size = max(1, current_batch_size // 2)
            torch.cuda.empty_cache()
            print(f"CUDA OOM: retrying this batch with batch_size={current_batch_size}")
        except Exception as error:
            if eager_auto_model is None:
                raise
            print(f"torch.compile failed ({type(error).__name__}); falling back to eager CUDA.")
            model[0].auto_model = eager_auto_model
            eager_auto_model = None


def token_batches(
    token_lengths: list[int],
    max_batch_tokens: int,
    max_batch_requests: int,
    length_bucket: bool,
) -> list[list[int]]:
    order = list(range(len(token_lengths)))
    if length_bucket:
        order.sort(key=token_lengths.__getitem__)
    batches: list[list[int]] = []
    batch: list[int] = []
    longest = 0
    for index in order:
        length = token_lengths[index]
        candidate_longest = max(longest, length)
        padded_tokens = candidate_longest * (len(batch) + 1)
        if batch and (len(batch) >= max_batch_requests or padded_tokens > max_batch_tokens):
            batches.append(batch)
            batch = []
            longest = 0
        batch.append(index)
        longest = max(longest, length)
    if batch:
        batches.append(batch)
    return batches


def prepare_pending_work(
    summary: dict[str, object],
    dataset_dir: Path,
    works_dir: Path,
    model: object,
    args: argparse.Namespace,
) -> PendingWork:
    work_id = int(summary["work_id"])
    final_dir = works_dir / str(work_id)
    temporary_dir = works_dir / f".{work_id}.tmp"
    if temporary_dir.exists():
        shutil.rmtree(temporary_dir)
    if final_dir.exists():
        shutil.rmtree(final_dir)
    temporary_dir.mkdir()
    rows = read_jsonl(dataset_dir / "works" / f"{work_id}.jsonl")
    if rows:
        tokenized = model.tokenizer(
            [row["text"] for row in rows],
            add_special_tokens=True,
            truncation=True,
            max_length=args.max_length,
            padding=False,
        )
        encoded_inputs = {
            key: [list(ids) for ids in values]
            for key, values in tokenized.items()
        }
        token_lengths = [len(ids) for ids in tokenized["input_ids"]]
    else:
        encoded_inputs = {"input_ids": [], "attention_mask": []}
        token_lengths = []
    return PendingWork(
        work_id=work_id,
        rows=rows,
        encoded_inputs=encoded_inputs,
        token_lengths=token_lengths,
        vectors=np.empty((len(rows), args.dimensions), dtype=np.float32),
        temporary_dir=temporary_dir,
        final_dir=final_dir,
    )


def prepare_pending_group(
    summaries: list[dict[str, object]],
    dataset_dir: Path,
    works_dir: Path,
    model: object,
    args: argparse.Namespace,
) -> tuple[list[PendingWork], int]:
    pending: list[PendingWork] = []
    skipped = 0
    for summary in summaries:
        work_id = int(summary["work_id"])
        final_dir = works_dir / str(work_id)
        if (final_dir / "metadata.json").exists() and not args.overwrite_work:
            skipped += 1
            continue
        pending.append(prepare_pending_work(summary, dataset_dir, works_dir, model, args))
    return pending, skipped


def publish_work(
    work: PendingWork,
    args: argparse.Namespace,
    compiled: bool,
    effective_batch_sizes: list[int],
) -> None:
    vectors = work.vectors
    work_batch_sizes = effective_batch_sizes if work.rows else []
    vectors /= np.maximum(np.linalg.norm(vectors, axis=1, keepdims=True), 1e-12)
    stored = vectors.astype(np.float16 if args.storage_dtype == "float16" else np.float32)
    with (work.temporary_dir / "embeddings.npy.tmp").open("wb") as handle:
        np.save(handle, stored, allow_pickle=False)
    os.replace(work.temporary_dir / "embeddings.npy.tmp", work.temporary_dir / "embeddings.npy")
    write_jsonl(work.temporary_dir / "chunks.jsonl", work.rows)
    write_json(
        work.temporary_dir / "metadata.json",
        {
            "work_id": work.work_id,
            "chunk_count": len(work.rows),
            "input_token_count": sum(work.token_lengths),
            "effective_batch_size_min": min(work_batch_sizes) if work_batch_sizes else None,
            "effective_batch_size_max": max(work_batch_sizes) if work_batch_sizes else None,
            "compiled": compiled,
            "shape": list(stored.shape),
            "dtype": str(stored.dtype),
            "completed_at": datetime.now(timezone.utc).isoformat(),
        },
    )
    work.final_dir.mkdir()
    for name in ("embeddings.npy", "chunks.jsonl", "metadata.json"):
        os.replace(work.temporary_dir / name, work.final_dir / name)
    work.temporary_dir.rmdir()


def main() -> None:
    args = parse_args()
    if args.batch_size < 1 or args.max_batch_tokens < 1 or args.work_buffer_size < 1:
        raise ValueError("Batch size, token budget, and work buffer size must be positive.")
    dataset_dir = ROOT / "data" / args.dataset_name
    prepared = load_json(dataset_dir / "manifest.json")
    output_dir = ROOT / "outputs" / safe_model_name(args.model) / args.output_name
    works_dir = output_dir / "works"
    if not args.overwrite_work and all(
        (works_dir / str(summary["work_id"]) / "metadata.json").exists()
        for summary in prepared["works"]
    ):
        print(f"Already complete: {output_dir}")
        return

    import torch
    device = args.device or ("cuda" if torch.cuda.is_available() else "cpu")
    if device == "cpu":
        print("WARNING: CUDA is unavailable; this model will be slow.")
    configure_cuda(torch, device)
    configure_sdpa(torch, device, args.sdpa_backend)
    model, effective_attention = load_model(args, device, torch)
    model.max_seq_length = args.max_length
    eager_auto_model = None
    if args.compile:
        eager_auto_model = model[0].auto_model
        model[0].auto_model = torch.compile(eager_auto_model, mode=args.compile_mode)

    works_dir.mkdir(parents=True, exist_ok=True)
    write_json(
        output_dir / "manifest.json",
        {
            "schema_version": 1,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "model": args.model,
            "max_length": args.max_length,
            "dimensions": args.dimensions,
            "storage_dtype": args.storage_dtype,
            "attention_requested": args.attention,
            "attention": effective_attention,
            "sdpa_backend": args.sdpa_backend,
            "compile": args.compile,
            "compile_mode": args.compile_mode if args.compile else None,
            "length_bucket": not args.no_length_bucket,
            "max_batch_tokens": args.max_batch_tokens,
            "max_batch_requests": args.batch_size,
            "work_buffer_size": args.work_buffer_size,
            "pretokenized_forward": True,
            "async_prepare": True,
            "normalized": True,
        },
    )

    started_at = time.perf_counter()
    total_input_tokens = 0
    total_padded_tokens = 0
    total_forward_seconds = 0.0
    summaries = prepared["works"]
    summary_groups = [
        summaries[start : start + args.work_buffer_size]
        for start in range(0, len(summaries), args.work_buffer_size)
    ]
    progress = tqdm(total=len(summaries), desc="Embedding", unit="work")
    with ThreadPoolExecutor(max_workers=1, thread_name_prefix="embed-prepare") as executor:
        future = executor.submit(
            prepare_pending_group,
            summary_groups[0],
            dataset_dir,
            works_dir,
            model,
            args,
        )
        for group_index in range(len(summary_groups)):
            pending, skipped = future.result()
            progress.update(skipped)
            if group_index + 1 < len(summary_groups):
                future = executor.submit(
                    prepare_pending_group,
                    summary_groups[group_index + 1],
                    dataset_dir,
                    works_dir,
                    model,
                    args,
                )
            if not pending:
                continue

            token_lengths: list[int] = []
            locations: list[tuple[int, int]] = []
            field_names = next(
                (tuple(work.encoded_inputs) for work in pending if work.rows),
                ("input_ids", "attention_mask"),
            )
            encoded_inputs: dict[str, list[list[int]]] = {key: [] for key in field_names}
            for work_index, work in enumerate(pending):
                for row_index, token_length in enumerate(work.token_lengths):
                    for key in field_names:
                        encoded_inputs[key].append(work.encoded_inputs[key][row_index])
                    token_lengths.append(token_length)
                    locations.append((work_index, row_index))

            batches = token_batches(
                token_lengths,
                args.max_batch_tokens,
                args.batch_size,
                not args.no_length_bucket,
            )
            effective_batch_sizes: list[int] = []
            for batch_indices in batches:
                batch_inputs = {
                    key: [values[index] for index in batch_indices]
                    for key, values in encoded_inputs.items()
                }
                (
                    batch_vectors,
                    effective_batch_size,
                    eager_auto_model,
                    padded_token_count,
                    forward_seconds,
                ) = encode_pre_tokenized_with_backoff(
                    model,
                    batch_inputs,
                    len(batch_indices),
                    torch,
                    eager_auto_model,
                )
                effective_batch_sizes.append(effective_batch_size)
                total_padded_tokens += padded_token_count
                total_forward_seconds += forward_seconds
                if args.dimensions < 1 or args.dimensions > batch_vectors.shape[1]:
                    raise ValueError(f"--dimensions must be in [1, {batch_vectors.shape[1]}]")
                batch_vectors = batch_vectors[:, : args.dimensions].astype(np.float32)
                for vector, flat_index in zip(batch_vectors, batch_indices):
                    work_index, row_index = locations[flat_index]
                    pending[work_index].vectors[row_index] = vector

            compiled = args.compile and eager_auto_model is not None
            for work in pending:
                publish_work(work, args, compiled, effective_batch_sizes)
                total_input_tokens += sum(work.token_lengths)
                progress.update()
            elapsed = max(time.perf_counter() - started_at, 0.001)
            batch_range = (
                f"{min(effective_batch_sizes)}-{max(effective_batch_sizes)}"
                if effective_batch_sizes
                else "empty"
            )
            padding_percent = (
                max(0.0, (total_padded_tokens / total_input_tokens - 1.0) * 100.0)
                if total_input_tokens
                else 0.0
            )
            progress.set_postfix(
                input_tokens=f"{total_input_tokens:,}",
                tok_s=f"{total_input_tokens / elapsed:,.0f}",
                gpu_tok_s=f"{total_input_tokens / max(total_forward_seconds, 0.001):,.0f}",
                padding=f"{padding_percent:.1f}%",
                batch=batch_range,
            )

    print(output_dir)


if __name__ == "__main__":
    main()
