from __future__ import annotations

import argparse
import os
import shutil
import time
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from tqdm import tqdm

from common import load_json, read_jsonl, safe_model_name, write_json, write_jsonl


ROOT = Path(__file__).resolve().parent
DEFAULT_MODEL = "Qwen/Qwen3-Embedding-4B"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Embed prepared works with Qwen3-Embedding-4B.")
    parser.add_argument("--dataset-name", default="latest-1000")
    parser.add_argument("--output-name", default="latest-1000")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--batch-size", type=int, default=8)
    parser.add_argument("--max-length", type=int, default=1024)
    parser.add_argument("--dimensions", type=int, default=1024)
    parser.add_argument("--storage-dtype", choices=("float16", "float32"), default="float16")
    parser.add_argument("--device")
    parser.add_argument("--overwrite-work", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    dataset_dir = ROOT / "data" / args.dataset_name
    prepared = load_json(dataset_dir / "manifest.json")

    import torch
    from sentence_transformers import SentenceTransformer

    device = args.device or ("cuda" if torch.cuda.is_available() else "cpu")
    if device == "cpu":
        print("WARNING: CUDA is unavailable; this model will be slow.")
    model = SentenceTransformer(
        args.model,
        device=device,
        model_kwargs={"torch_dtype": torch.float16 if device != "cpu" else torch.float32},
        tokenizer_kwargs={"padding_side": "left"},
    )
    model.max_seq_length = args.max_length

    output_dir = ROOT / "outputs" / safe_model_name(args.model) / args.output_name
    works_dir = output_dir / "works"
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
            "normalized": True,
        },
    )

    started_at = time.perf_counter()
    total_input_tokens = 0
    progress = tqdm(prepared["works"], desc="Embedding", unit="work")
    for summary in progress:
        work_id = int(summary["work_id"])
        final_dir = works_dir / str(work_id)
        if (final_dir / "metadata.json").exists() and not args.overwrite_work:
            continue
        temporary_dir = works_dir / f".{work_id}.tmp"
        if temporary_dir.exists():
            shutil.rmtree(temporary_dir)
        if final_dir.exists():
            shutil.rmtree(final_dir)
        temporary_dir.mkdir()

        rows = read_jsonl(dataset_dir / "works" / f"{work_id}.jsonl")
        texts = [row["text"] for row in rows]
        # Count the exact input after the same truncation used by the model.
        # This tokenization is deliberately kept outside the timed model call:
        # tok/s below is end-to-end throughput, including this CPU work.
        tokenized = model.tokenizer(
            texts,
            add_special_tokens=True,
            truncation=True,
            max_length=args.max_length,
            padding=False,
        )
        input_token_count = sum(len(ids) for ids in tokenized["input_ids"])
        vectors = model.encode(
            texts,
            batch_size=args.batch_size,
            convert_to_numpy=True,
            normalize_embeddings=True,
            show_progress_bar=False,
        )
        vectors = np.asarray(vectors)
        if args.dimensions < 1 or args.dimensions > vectors.shape[1]:
            raise ValueError(f"--dimensions must be in [1, {vectors.shape[1]}]")
        vectors = vectors[:, : args.dimensions].astype(np.float32)
        vectors /= np.linalg.norm(vectors, axis=1, keepdims=True)
        stored = vectors.astype(np.float16 if args.storage_dtype == "float16" else np.float32)

        with (temporary_dir / "embeddings.npy.tmp").open("wb") as handle:
            np.save(handle, stored, allow_pickle=False)
        os.replace(temporary_dir / "embeddings.npy.tmp", temporary_dir / "embeddings.npy")
        write_jsonl(temporary_dir / "chunks.jsonl", rows)
        write_json(
            temporary_dir / "metadata.json",
            {
                "work_id": work_id,
                "chunk_count": len(rows),
                "input_token_count": input_token_count,
                "shape": list(stored.shape),
                "dtype": str(stored.dtype),
                "completed_at": datetime.now(timezone.utc).isoformat(),
            },
        )
        # Windows rejects moving the completed directory itself in this tree.
        # Publish its closed files one by one instead; every later run only
        # treats a work as complete once metadata.json has arrived.
        final_dir.mkdir()
        for name in ("embeddings.npy", "chunks.jsonl", "metadata.json"):
            os.replace(temporary_dir / name, final_dir / name)
        temporary_dir.rmdir()
        total_input_tokens += input_token_count
        elapsed = max(time.perf_counter() - started_at, 0.001)
        progress.set_postfix(
            input_tokens=f"{total_input_tokens:,}",
            tok_s=f"{total_input_tokens / elapsed:,.0f}",
        )

    print(output_dir)


if __name__ == "__main__":
    main()
