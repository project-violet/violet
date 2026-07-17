from __future__ import annotations

import argparse
import json
import os
import statistics
import time
from pathlib import Path
from typing import Any, Iterator

import faiss
import numpy as np
from tqdm import tqdm

from accelerated_index import CompactMetadata, METADATA_HEADER
from common import load_json, safe_model_name, write_json
from search import (
    DEFAULT_EMBEDDING_MODEL,
    DEFAULT_INDEX_MODEL,
    INSTRUCTION,
    LOCATION_DTYPE,
    post_json,
)


ROOT = Path(__file__).resolve().parent
DEFAULT_QUERIES = ROOT / "benchmark-queries.txt"


def add_common_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--output-name", default="latest-5000")
    parser.add_argument("--model", default=DEFAULT_INDEX_MODEL)
    parser.add_argument("--index-name", default="index")
    parser.add_argument("--threads", type=int, default=16)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build and A/B benchmark compact indexes without running reranking."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    build = subparsers.add_parser("build", help="Build a reusable FAISS index.")
    add_common_args(build)
    build.add_argument("--kind", choices=("sq8", "ivf-sq8"), default="sq8")
    build.add_argument("--training-rows", type=int, default=100_000)
    build.add_argument("--add-batch-rows", type=int, default=32_768)
    build.add_argument("--nlist", type=int, default=2048)
    build.add_argument("--max-vectors", type=int, default=None)
    build.add_argument("--overwrite", action="store_true")

    metadata = subparsers.add_parser(
        "build-metadata", help="Pack reranking metadata into one random-access file."
    )
    add_common_args(metadata)
    metadata.add_argument("--prefix", default="compact-metadata")
    metadata.add_argument("--buffer-bytes", type=int, default=8 * 1024 * 1024)
    metadata.add_argument("--max-vectors", type=int, default=None)
    metadata.add_argument("--overwrite", action="store_true")

    bench = subparsers.add_parser("bench", help="Compare FAISS against the current scan.")
    add_common_args(bench)
    bench.add_argument("--faiss-index", default="faiss-sq8.index")
    bench.add_argument("--metadata-prefix", default="compact-metadata")
    bench.add_argument("--queries", type=Path, default=DEFAULT_QUERIES)
    bench.add_argument("--candidate-k", type=int, default=500)
    bench.add_argument("--recall-k", type=int, nargs="+", default=(100, 500))
    bench.add_argument("--block-rows", type=int, default=32_768)
    bench.add_argument("--nprobe", type=int, nargs="+", default=(16, 32, 64))
    bench.add_argument("--embedding-url", default="http://127.0.0.1:8081/v1/embeddings")
    bench.add_argument("--embedding-model", default=DEFAULT_EMBEDDING_MODEL)
    bench.add_argument("--timeout", type=float, default=300.0)
    bench.add_argument(
        "--report",
        type=Path,
        default=ROOT / ".runtime" / "search-index-benchmark.json",
    )
    return parser.parse_args()


def load_source(output_name: str, model: str, index_name: str) -> tuple[Path, Path, dict[str, Any]]:
    output_dir = ROOT / "outputs" / safe_model_name(model) / output_name
    index_dir = output_dir / index_name
    manifest = load_json(index_dir / "manifest.json")
    return output_dir, index_dir, manifest


def iter_vector_blocks(
    index_dir: Path,
    manifest: dict[str, Any],
    block_rows: int,
    limit: int | None = None,
) -> Iterator[tuple[int, np.ndarray]]:
    dimensions = int(manifest["dimensions"])
    storage_dtype = np.dtype(str(manifest["storage_dtype"]))
    remaining = int(manifest["vector_count"]) if limit is None else limit
    for shard in manifest["shards"]:
        if remaining <= 0:
            break
        shard_count = min(int(shard["count"]), remaining)
        vectors = np.memmap(
            index_dir / str(shard["file"]),
            mode="r",
            dtype=storage_dtype,
            shape=(int(shard["count"]), dimensions),
        )
        shard_start = int(shard["start"])
        for block_start in range(0, shard_count, block_rows):
            block_end = min(block_start + block_rows, shard_count)
            yield shard_start + block_start, np.ascontiguousarray(
                vectors[block_start:block_end], dtype=np.float32
            )
        remaining -= shard_count


def training_sample(
    index_dir: Path,
    manifest: dict[str, Any],
    rows: int,
    limit: int,
) -> np.ndarray:
    dimensions = int(manifest["dimensions"])
    rows = min(rows, limit)
    positions = np.linspace(0, limit - 1, rows, dtype=np.int64)
    sample = np.empty((rows, dimensions), dtype=np.float32)
    cursor = 0
    position_cursor = 0
    for shard in manifest["shards"]:
        shard_start = int(shard["start"])
        shard_count = int(shard["count"])
        shard_end = min(shard_start + shard_count, limit)
        if shard_start >= limit:
            break
        next_cursor = int(np.searchsorted(positions, shard_end, side="left"))
        selected = positions[position_cursor:next_cursor] - shard_start
        if len(selected):
            vectors = np.memmap(
                index_dir / str(shard["file"]),
                mode="r",
                dtype=np.dtype(str(manifest["storage_dtype"])),
                shape=(shard_count, dimensions),
            )
            sample[cursor : cursor + len(selected)] = vectors[selected]
            cursor += len(selected)
        position_cursor = next_cursor
    if cursor != rows:
        raise RuntimeError(f"Collected {cursor:,} training rows, expected {rows:,}")
    return sample


def faiss_filename(kind: str, max_vectors: int | None) -> str:
    suffix = "" if max_vectors is None else f"-{max_vectors}"
    return f"faiss-{kind}{suffix}.index"


def build_index(args: argparse.Namespace) -> None:
    _, index_dir, manifest = load_source(args.output_name, args.model, args.index_name)
    dimensions = int(manifest["dimensions"])
    source_count = int(manifest["vector_count"])
    vector_count = source_count if args.max_vectors is None else min(args.max_vectors, source_count)
    if vector_count < 1 or args.training_rows < 1 or args.add_batch_rows < 1:
        raise ValueError("vector and batch counts must be positive")
    if args.kind == "ivf-sq8" and args.nlist < 1:
        raise ValueError("--nlist must be positive")

    output_path = index_dir / faiss_filename(args.kind, args.max_vectors)
    if output_path.exists() and not args.overwrite:
        raise FileExistsError(f"FAISS index already exists: {output_path}; pass --overwrite")

    faiss.omp_set_num_threads(args.threads)
    sample_started = time.perf_counter()
    sample = training_sample(index_dir, manifest, args.training_rows, vector_count)
    sample_elapsed = time.perf_counter() - sample_started

    if args.kind == "sq8":
        index: Any = faiss.IndexScalarQuantizer(
            dimensions,
            faiss.ScalarQuantizer.QT_8bit,
            faiss.METRIC_INNER_PRODUCT,
        )
    else:
        coarse = faiss.IndexFlatIP(dimensions)
        index = faiss.IndexIVFScalarQuantizer(
            coarse,
            dimensions,
            args.nlist,
            faiss.ScalarQuantizer.QT_8bit,
            faiss.METRIC_INNER_PRODUCT,
        )

    train_started = time.perf_counter()
    index.train(sample)
    train_elapsed = time.perf_counter() - train_started
    del sample

    add_started = time.perf_counter()
    progress = tqdm(total=vector_count, desc=f"Building {args.kind}", unit="vector", dynamic_ncols=True)
    try:
        for _, block in iter_vector_blocks(
            index_dir, manifest, args.add_batch_rows, vector_count
        ):
            index.add(block)
            progress.update(len(block))
    finally:
        progress.close()
    add_elapsed = time.perf_counter() - add_started

    faiss.write_index(index, str(output_path))
    size = output_path.stat().st_size
    metadata = {
        "built_at_ns": time.time_ns(),
        "kind": args.kind,
        "dimensions": dimensions,
        "vector_count": int(index.ntotal),
        "source_vector_count": source_count,
        "training_rows": min(args.training_rows, vector_count),
        "nlist": args.nlist if args.kind == "ivf-sq8" else None,
        "size_bytes": size,
        "sample_seconds": sample_elapsed,
        "train_seconds": train_elapsed,
        "add_seconds": add_elapsed,
    }
    write_json(output_path.with_suffix(".json"), metadata)
    print(json.dumps(metadata, ensure_ascii=False, indent=2))
    print(f"Index: {output_path}")


def read_jsonl_fast(path: Path) -> list[dict[str, Any]]:
    try:
        import orjson
    except ImportError:
        return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line]
    return [orjson.loads(line) for line in path.read_bytes().splitlines() if line]


def build_metadata(args: argparse.Namespace) -> None:
    output_dir, index_dir, manifest = load_source(args.output_name, args.model, args.index_name)
    source_vector_count = int(manifest["vector_count"])
    vector_count = (
        source_vector_count
        if args.max_vectors is None
        else min(args.max_vectors, source_vector_count)
    )
    if vector_count < 1:
        raise ValueError("--max-vectors must be positive")
    locations = np.memmap(
        index_dir / "locations.bin",
        mode="r",
        dtype=LOCATION_DTYPE,
        shape=(source_vector_count,),
    )
    records_path = index_dir / f"{args.prefix}.bin"
    offsets_path = index_dir / f"{args.prefix}-offsets.bin"
    metadata_path = index_dir / f"{args.prefix}.json"
    if not args.overwrite and any(path.exists() for path in (records_path, offsets_path, metadata_path)):
        raise FileExistsError(f"Metadata files already exist for prefix {args.prefix}; pass --overwrite")
    if args.buffer_bytes < 1:
        raise ValueError("--buffer-bytes must be positive")

    records_tmp = records_path.with_suffix(records_path.suffix + ".tmp")
    offsets_tmp = offsets_path.with_suffix(offsets_path.suffix + ".tmp")
    for path in (records_tmp, offsets_tmp):
        if path.exists():
            path.unlink()

    offsets = np.memmap(offsets_tmp, mode="w+", dtype="<u8", shape=(vector_count + 1,))
    current_work = None
    current_rows: list[dict[str, Any]] = []
    record_offset = 0
    buffer = bytearray()
    started = time.perf_counter()
    progress = tqdm(total=vector_count, desc="Packing metadata", unit="row", dynamic_ncols=True)
    try:
        with records_tmp.open("wb", buffering=args.buffer_bytes) as records:
            for row_id in range(vector_count):
                location = locations[row_id]
                work_id = int(location["work_id"])
                chunk_index = int(location["chunk_index"])
                if work_id != current_work:
                    current_rows = read_jsonl_fast(
                        output_dir / "works" / str(work_id) / "chunks.jsonl"
                    )
                    current_work = work_id
                if chunk_index >= len(current_rows):
                    raise RuntimeError(
                        f"Location {row_id} points past work {work_id}: {chunk_index}"
                    )
                row = current_rows[chunk_index]
                pages = np.asarray(row["page_ids"], dtype="<i4")
                text_bytes = str(row["text"]).encode("utf-8")
                if len(pages) > 65535:
                    raise RuntimeError(f"Too many pages in row {row_id}: {len(pages)}")
                offsets[row_id] = record_offset
                header = METADATA_HEADER.pack(work_id, len(pages), len(text_bytes))
                buffer.extend(header)
                buffer.extend(pages.tobytes())
                buffer.extend(text_bytes)
                record_offset += len(header) + pages.nbytes + len(text_bytes)
                if len(buffer) >= args.buffer_bytes:
                    records.write(buffer)
                    buffer.clear()
                progress.update(1)
            if buffer:
                records.write(buffer)
            offsets[vector_count] = record_offset
            offsets.flush()
    finally:
        progress.close()
        mmap_handle = getattr(offsets, "_mmap", None)
        if mmap_handle is not None:
            mmap_handle.close()

    os.replace(records_tmp, records_path)
    os.replace(offsets_tmp, offsets_path)
    elapsed = time.perf_counter() - started
    metadata = {
        "built_at_ns": time.time_ns(),
        "schema_version": 1,
        "vector_count": vector_count,
        "record_header": "<qHI",
        "records_file": records_path.name,
        "offsets_file": offsets_path.name,
        "records_bytes": records_path.stat().st_size,
        "offsets_bytes": offsets_path.stat().st_size,
        "elapsed_seconds": elapsed,
    }
    write_json(metadata_path, metadata)
    print(json.dumps(metadata, ensure_ascii=False, indent=2))
    print(f"Metadata: {metadata_path}")


def embed_query(args: argparse.Namespace, query: str, dimensions: int) -> np.ndarray:
    prompt = f"Instruct: {INSTRUCTION}\nQuery: {query}"
    response = post_json(
        args.embedding_url,
        {"model": args.embedding_model, "input": [prompt], "encoding_format": "float"},
        args.timeout,
    )
    vector = np.asarray(response["data"][0]["embedding"], dtype=np.float32)[:dimensions]
    norm = float(np.linalg.norm(vector))
    if not np.isfinite(norm) or norm <= 0:
        raise RuntimeError(f"Invalid embedding for query: {query}")
    return np.ascontiguousarray(vector / norm)


def exact_search(
    index_dir: Path,
    manifest: dict[str, Any],
    query: np.ndarray,
    k: int,
    block_rows: int,
    limit: int,
) -> tuple[np.ndarray, np.ndarray]:
    best_scores = np.empty(0, dtype=np.float32)
    best_ids = np.empty(0, dtype=np.int64)
    for block_start, block in iter_vector_blocks(index_dir, manifest, block_rows, limit):
        scores = block @ query
        count = min(k, len(scores))
        local = np.argpartition(scores, len(scores) - count)[-count:]
        candidate_scores = np.concatenate((best_scores, scores[local]))
        candidate_ids = np.concatenate((best_ids, block_start + local.astype(np.int64)))
        keep = min(k, len(candidate_scores))
        selected = np.argpartition(candidate_scores, len(candidate_scores) - keep)[-keep:]
        best_scores = candidate_scores[selected]
        best_ids = candidate_ids[selected]
    order = np.argsort(best_scores)[::-1]
    return best_scores[order], best_ids[order]


def materialize_json(
    output_dir: Path,
    index_dir: Path,
    manifest: dict[str, Any],
    row_ids: np.ndarray,
) -> tuple[int, int]:
    locations = np.memmap(
        index_dir / "locations.bin",
        mode="r",
        dtype=LOCATION_DTYPE,
        shape=(int(manifest["vector_count"]),),
    )
    work_ids = {int(locations[int(row_id)]["work_id"]) for row_id in row_ids}
    rows = 0
    for work_id in work_ids:
        path = output_dir / "works" / str(work_id) / "chunks.jsonl"
        with path.open("r", encoding="utf-8") as handle:
            for line in handle:
                if line.strip():
                    json.loads(line)
                    rows += 1
    return len(work_ids), rows


def recall(reference: np.ndarray, candidate: np.ndarray, k: int) -> float:
    reference_set = set(map(int, reference[:k]))
    candidate_set = set(map(int, candidate[:k]))
    return len(reference_set & candidate_set) / max(1, len(reference_set))


def benchmark(args: argparse.Namespace) -> None:
    output_dir, index_dir, manifest = load_source(args.output_name, args.model, args.index_name)
    faiss_path = index_dir / args.faiss_index
    if not faiss_path.is_file():
        raise FileNotFoundError(f"FAISS index not found: {faiss_path}")
    queries = [
        line.strip()
        for line in args.queries.read_text(encoding="utf-8-sig").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    if not queries:
        raise ValueError(f"No queries found in {args.queries}")
    if args.candidate_k < max(args.recall_k):
        raise ValueError("--candidate-k must be at least the largest --recall-k")

    faiss.omp_set_num_threads(args.threads)
    load_started = time.perf_counter()
    compact = faiss.read_index(str(faiss_path))
    load_elapsed = time.perf_counter() - load_started
    limit = int(compact.ntotal)
    dimensions = int(manifest["dimensions"])
    is_ivf = isinstance(compact, faiss.IndexIVF)
    settings = args.nprobe if is_ivf else (0,)
    metadata = CompactMetadata(index_dir, args.metadata_prefix, limit)

    report: dict[str, Any] = {
        "index": str(faiss_path),
        "index_type": type(compact).__name__,
        "index_bytes": faiss_path.stat().st_size,
        "index_load_seconds": load_elapsed,
        "vector_count": limit,
        "dimensions": dimensions,
        "candidate_k": args.candidate_k,
        "queries": [],
    }

    print(
        f"Loaded {type(compact).__name__}: {limit:,} vectors, "
        f"{faiss_path.stat().st_size / 2**30:.2f} GiB in {load_elapsed:.2f}s"
    )
    for query_text in queries:
        query = embed_query(args, query_text, dimensions)

        exact_started = time.perf_counter()
        exact_scores, exact_ids = exact_search(
            index_dir, manifest, query, args.candidate_k, args.block_rows, limit
        )
        exact_elapsed = time.perf_counter() - exact_started

        json_started = time.perf_counter()
        unique_works, parsed_rows = materialize_json(
            output_dir, index_dir, manifest, exact_ids
        )
        json_elapsed = time.perf_counter() - json_started

        metadata_started = time.perf_counter()
        compact_rows = [metadata.get(int(row_id)) for row_id in exact_ids]
        metadata_elapsed = time.perf_counter() - metadata_started
        if len(compact_rows) != len(exact_ids):
            raise RuntimeError("Compact metadata returned an unexpected row count")

        query_report: dict[str, Any] = {
            "query": query_text,
            "exact_seconds": exact_elapsed,
            "json_seconds": json_elapsed,
            "metadata_seconds": metadata_elapsed,
            "unique_works": unique_works,
            "parsed_json_rows": parsed_rows,
            "variants": [],
        }
        for nprobe in settings:
            if is_ivf:
                compact.nprobe = nprobe
            compact_started = time.perf_counter()
            compact_scores, compact_ids = compact.search(
                query.reshape(1, -1), args.candidate_k
            )
            compact_elapsed = time.perf_counter() - compact_started
            ids = compact_ids[0]
            variant = {
                "nprobe": nprobe if is_ivf else None,
                "seconds": compact_elapsed,
                "recall": {str(k): recall(exact_ids, ids, k) for k in args.recall_k},
            }
            query_report["variants"].append(variant)
        report["queries"].append(query_report)
        best = query_report["variants"][-1]
        recall_text = ", ".join(
            f"R@{k}={best['recall'][str(k)] * 100:.1f}%" for k in args.recall_k
        )
        print(
            f"{query_text}: exact={exact_elapsed:.3f}s json={json_elapsed:.3f}s "
            f"metadata={metadata_elapsed:.3f}s compact={best['seconds']:.3f}s "
            f"{recall_text} works={unique_works}"
        )

    exact_times = [row["exact_seconds"] for row in report["queries"]]
    json_times = [row["json_seconds"] for row in report["queries"]]
    metadata_times = [row["metadata_seconds"] for row in report["queries"]]
    summary_variants = []
    for variant_index, nprobe in enumerate(settings):
        rows = [query["variants"][variant_index] for query in report["queries"]]
        summary_variants.append(
            {
                "nprobe": nprobe if is_ivf else None,
                "median_seconds": statistics.median(row["seconds"] for row in rows),
                "mean_recall": {
                    str(k): statistics.mean(row["recall"][str(k)] for row in rows)
                    for k in args.recall_k
                },
            }
        )
    report["summary"] = {
        "exact_median_seconds": statistics.median(exact_times),
        "json_median_seconds": statistics.median(json_times),
        "metadata_median_seconds": statistics.median(metadata_times),
        "variants": summary_variants,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    write_json(args.report, report)
    metadata.close()
    print(json.dumps(report["summary"], ensure_ascii=False, indent=2))
    print(f"Report: {args.report}")


def main() -> None:
    args = parse_args()
    if args.threads < 1:
        raise ValueError("--threads must be positive")
    if args.command == "build":
        build_index(args)
    elif args.command == "build-metadata":
        build_metadata(args)
    else:
        benchmark(args)


if __name__ == "__main__":
    main()
