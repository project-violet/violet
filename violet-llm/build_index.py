from __future__ import annotations

import argparse
import os
import shutil
import time
from concurrent.futures import FIRST_COMPLETED, Future, ThreadPoolExecutor, wait
from pathlib import Path
from typing import Iterator

import numpy as np
from tqdm import tqdm

from common import load_json, safe_model_name, write_json


ROOT = Path(__file__).resolve().parent
DEFAULT_MODEL = "Qwen/Qwen3-Embedding-4B"
LOCATION_DTYPE = np.dtype([("work_id", "<i8"), ("chunk_index", "<i4")])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Combine per-work embeddings into a few search shards."
    )
    parser.add_argument("--output-name", default="latest-5000")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--index-name", default="index")
    parser.add_argument("--shard-rows", type=int, default=100_000)
    parser.add_argument(
        "--workers",
        type=int,
        default=min(8, max(1, os.cpu_count() or 1)),
        help="Parallel readers used to prefetch small source files.",
    )
    parser.add_argument(
        "--prefetch",
        type=int,
        default=0,
        help="Maximum queued reads; defaults to twice --workers.",
    )
    parser.add_argument("--max-works", type=int, default=None, help="Build a partial smoke-test index.")
    parser.add_argument("--overwrite", action="store_true")
    return parser.parse_args()


def list_work_dirs(works_dir: Path, max_works: int | None) -> list[Path]:
    work_dirs = [
        path
        for path in works_dir.iterdir()
        if path.is_dir()
        and path.name.isdigit()
        and (path / "embeddings.npy").is_file()
        and (path / "chunks.jsonl").is_file()
    ]
    work_dirs.sort(key=lambda path: int(path.name), reverse=True)
    if max_works is not None:
        if max_works < 1:
            raise ValueError("--max-works must be positive")
        work_dirs = work_dirs[:max_works]
    if not work_dirs:
        raise RuntimeError(f"No completed work embeddings found under {works_dir}")
    return work_dirs


def load_vectors(work_dir: Path, dimensions: int, dtype: np.dtype) -> tuple[int, np.ndarray]:
    vectors = np.load(work_dir / "embeddings.npy", allow_pickle=False)
    if vectors.ndim != 2 or vectors.shape[1] != dimensions:
        raise RuntimeError(
            f"Unexpected vector shape for work {work_dir.name}: {vectors.shape}; "
            f"expected (*, {dimensions})"
        )
    if vectors.dtype != dtype:
        vectors = vectors.astype(dtype, copy=False)
    return int(work_dir.name), np.ascontiguousarray(vectors)


def iter_loaded_works(
    work_dirs: list[Path],
    dimensions: int,
    dtype: np.dtype,
    workers: int,
    prefetch: int,
) -> Iterator[tuple[int, np.ndarray]]:
    if workers <= 1:
        for work_dir in work_dirs:
            yield load_vectors(work_dir, dimensions, dtype)
        return

    source = iter(work_dirs)
    with ThreadPoolExecutor(max_workers=workers, thread_name_prefix="index-reader") as executor:
        pending: dict[Future[tuple[int, np.ndarray]], Path] = {}

        def submit_one() -> bool:
            try:
                work_dir = next(source)
            except StopIteration:
                return False
            pending[executor.submit(load_vectors, work_dir, dimensions, dtype)] = work_dir
            return True

        for _ in range(max(workers, prefetch)):
            if not submit_one():
                break
        while pending:
            completed, _ = wait(pending, return_when=FIRST_COMPLETED)
            for future in completed:
                work_dir = pending.pop(future)
                try:
                    yield future.result()
                except Exception as error:
                    raise RuntimeError(f"Failed to read work {work_dir.name}") from error
                submit_one()


class ShardWriter:
    def __init__(self, output_dir: Path, dimensions: int, dtype: np.dtype, shard_rows: int) -> None:
        self.output_dir = output_dir
        self.dimensions = dimensions
        self.dtype = dtype
        self.shard_rows = shard_rows
        self.locations_handle = (output_dir / "locations.bin").open("wb")
        self.shard_handle = None
        self.shard_name = ""
        self.shard_start = 0
        self.shard_count = 0
        self.total_count = 0
        self.shards: list[dict[str, int | str]] = []

    def _open_shard(self) -> None:
        self.shard_name = f"embeddings-{len(self.shards):05d}.bin"
        self.shard_handle = (self.output_dir / self.shard_name).open("wb")
        self.shard_start = self.total_count
        self.shard_count = 0

    def _close_shard(self) -> None:
        if self.shard_handle is None:
            return
        self.shard_handle.close()
        self.shards.append(
            {"file": self.shard_name, "start": self.shard_start, "count": self.shard_count}
        )
        self.shard_handle = None

    def write(self, work_id: int, vectors: np.ndarray) -> None:
        source_offset = 0
        while source_offset < len(vectors):
            if self.shard_handle is None:
                self._open_shard()
            take = min(self.shard_rows - self.shard_count, len(vectors) - source_offset)
            vectors[source_offset : source_offset + take].tofile(self.shard_handle)
            locations = np.empty(take, dtype=LOCATION_DTYPE)
            locations["work_id"] = work_id
            locations["chunk_index"] = np.arange(
                source_offset, source_offset + take, dtype=np.int32
            )
            locations.tofile(self.locations_handle)
            source_offset += take
            self.shard_count += take
            self.total_count += take
            if self.shard_count == self.shard_rows:
                self._close_shard()

    def close(self) -> None:
        self._close_shard()
        if not self.locations_handle.closed:
            self.locations_handle.close()


def main() -> None:
    args = parse_args()
    if args.shard_rows < 1 or args.workers < 1:
        raise ValueError("--shard-rows and --workers must be positive")
    prefetch = args.prefetch or args.workers * 2
    if prefetch < 1:
        raise ValueError("--prefetch must be positive")

    output_dir = ROOT / "outputs" / safe_model_name(args.model) / args.output_name
    source_manifest = load_json(output_dir / "manifest.json")
    dimensions = int(source_manifest["dimensions"])
    storage_dtype = np.dtype(str(source_manifest["storage_dtype"]))
    work_dirs = list_work_dirs(output_dir / "works", args.max_works)

    final_dir = output_dir / args.index_name
    if final_dir.exists() and not args.overwrite:
        raise FileExistsError(f"Index already exists: {final_dir}; pass --overwrite")
    temporary_dir = output_dir / f".{args.index_name}.building-{os.getpid()}"
    if temporary_dir.exists():
        shutil.rmtree(temporary_dir)
    temporary_dir.mkdir(parents=True)

    started = time.perf_counter()
    writer = ShardWriter(temporary_dir, dimensions, storage_dtype, args.shard_rows)
    progress = tqdm(total=len(work_dirs), desc="Building index", unit="work", dynamic_ncols=True)
    try:
        loaded = iter_loaded_works(
            work_dirs, dimensions, storage_dtype, args.workers, prefetch
        )
        for work_id, vectors in loaded:
            writer.write(work_id, vectors)
            progress.update(1)
            if progress.n % 100 == 0 or progress.n == progress.total:
                progress.set_postfix(
                    vectors=f"{writer.total_count:,}",
                    shards=len(writer.shards) + int(writer.shard_handle is not None),
                    refresh=False,
                )
        writer.close()
    except Exception:
        writer.close()
        raise
    finally:
        progress.close()

    elapsed = time.perf_counter() - started
    vector_bytes = writer.total_count * dimensions * storage_dtype.itemsize
    write_json(
        temporary_dir / "manifest.json",
        {
            "schema_version": 1,
            "model": args.model,
            "source_output": args.output_name,
            "dimensions": dimensions,
            "storage_dtype": storage_dtype.name,
            "normalized": bool(source_manifest.get("normalized", True)),
            "work_count": len(work_dirs),
            "vector_count": writer.total_count,
            "location_dtype": LOCATION_DTYPE.descr,
            "shard_rows": args.shard_rows,
            "shards": writer.shards,
        },
    )
    if final_dir.exists():
        shutil.rmtree(final_dir)
    os.replace(temporary_dir, final_dir)
    print(
        f"Built {len(writer.shards):,} shards with {writer.total_count:,} vectors from "
        f"{len(work_dirs):,} works in {elapsed:.1f}s "
        f"({writer.total_count / max(elapsed, 1e-9):,.0f} vectors/s, "
        f"{vector_bytes / 1_000_000_000:.2f} GB)."
    )
    print(f"Index: {final_dir}")


if __name__ == "__main__":
    main()
