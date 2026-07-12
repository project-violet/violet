from __future__ import annotations

import argparse
import json
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import numpy as np

from common import load_json, read_jsonl, safe_model_name


ROOT = Path(__file__).resolve().parent
DEFAULT_MODEL = "Qwen/Qwen3-Embedding-4B"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Benchmark a TEI embedding endpoint.")
    parser.add_argument("--dataset-name", default="benchmark-20")
    parser.add_argument("--endpoint", default="http://127.0.0.1:8080/embed")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--max-length", type=int, default=1024)
    parser.add_argument("--dimensions", type=int, default=1024)
    parser.add_argument("--client-batch-size", type=int, default=32)
    parser.add_argument("--concurrency", type=int, default=1)
    parser.add_argument("--reference-output")
    return parser.parse_args()


def request_embeddings(endpoint: str, texts: list[str]) -> np.ndarray:
    payload = json.dumps({"inputs": texts, "truncate": True}).encode("utf-8")
    request = urllib.request.Request(
        endpoint,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=300) as response:
        return np.asarray(json.load(response), dtype=np.float32)


def main() -> None:
    args = parse_args()
    if args.client_batch_size < 1 or args.concurrency < 1:
        raise ValueError("Batch size and concurrency must be positive.")

    dataset_dir = ROOT / "data" / args.dataset_name
    manifest = load_json(dataset_dir / "manifest.json")
    texts: list[str] = []
    work_sizes: list[tuple[int, int]] = []
    for summary in manifest["works"]:
        work_id = int(summary["work_id"])
        rows = read_jsonl(dataset_dir / "works" / f"{work_id}.jsonl")
        texts.extend(str(row["text"]) for row in rows)
        work_sizes.append((work_id, len(rows)))

    from transformers import AutoTokenizer

    tokenizer = AutoTokenizer.from_pretrained(args.model, local_files_only=True)
    tokenized = tokenizer(
        texts,
        add_special_tokens=True,
        truncation=True,
        max_length=args.max_length,
        padding=False,
    )
    input_tokens = sum(len(ids) for ids in tokenized["input_ids"])
    batches = [
        texts[start : start + args.client_batch_size]
        for start in range(0, len(texts), args.client_batch_size)
    ]

    request_embeddings(args.endpoint, texts[: min(2, len(texts))])
    started_at = time.perf_counter()
    results: list[np.ndarray | None] = [None] * len(batches)
    with ThreadPoolExecutor(max_workers=args.concurrency) as executor:
        futures = {
            executor.submit(request_embeddings, args.endpoint, batch): index
            for index, batch in enumerate(batches)
        }
        for future in as_completed(futures):
            results[futures[future]] = future.result()
    elapsed = time.perf_counter() - started_at
    vectors = np.concatenate([result for result in results if result is not None], axis=0)
    if args.dimensions > vectors.shape[1]:
        raise ValueError(f"Requested {args.dimensions} dimensions from {vectors.shape[1]}")
    vectors = vectors[:, : args.dimensions]
    vectors /= np.maximum(np.linalg.norm(vectors, axis=1, keepdims=True), 1e-12)

    print(
        f"rows={len(vectors):,} input_tokens={input_tokens:,} elapsed={elapsed:.3f}s "
        f"tok_s={input_tokens / elapsed:,.0f} rows_s={len(vectors) / elapsed:,.1f} "
        f"concurrency={args.concurrency} client_batch={args.client_batch_size}"
    )

    if not args.reference_output:
        return
    reference_root = (
        ROOT
        / "outputs"
        / safe_model_name(args.model)
        / args.reference_output
        / "works"
    )
    reference_parts: list[np.ndarray] = []
    for work_id, size in work_sizes:
        reference = np.asarray(
            np.load(reference_root / str(work_id) / "embeddings.npy", allow_pickle=False),
            dtype=np.float32,
        )
        if len(reference) != size:
            raise ValueError(f"Reference row mismatch for work {work_id}")
        reference_parts.append(reference)
    reference_vectors = np.concatenate(reference_parts, axis=0)
    cosine = np.sum(vectors * reference_vectors, axis=1) / (
        np.linalg.norm(vectors, axis=1) * np.linalg.norm(reference_vectors, axis=1)
    )
    print(
        f"reference_min_cosine={float(cosine.min()):.8f} "
        f"reference_mean_cosine={float(cosine.mean()):.8f} "
        f"max_abs_diff={float(np.max(np.abs(vectors - reference_vectors))):.8f}"
    )


if __name__ == "__main__":
    main()
