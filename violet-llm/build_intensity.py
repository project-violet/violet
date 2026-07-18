from __future__ import annotations

import argparse
import json
import os
import re
import time
from concurrent.futures import FIRST_COMPLETED, Future, ThreadPoolExecutor, wait
from pathlib import Path
from typing import Iterator
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

os.environ.setdefault("OMP_NUM_THREADS", "1")
os.environ.setdefault("OPENBLAS_NUM_THREADS", "1")
os.environ.setdefault("MKL_NUM_THREADS", "1")

import numpy as np
import orjson
from tqdm import tqdm

from common import load_json, safe_model_name


ROOT = Path(__file__).resolve().parent
DEFAULT_MODEL = "Qwen/Qwen3-Embedding-4B"
DEFAULT_EMBEDDING_MODEL = "Qwen/Qwen3-Embedding-4B-GGUF:Q5_K_M"
DEFAULT_OUTPUT_FILE = "intensity-timelines.jsonl"
SCHEMA_VERSION = 1
METHOD_VERSION = 1
PAGE_IDS_PATTERN = re.compile(rb'"page_ids":\[([0-9,]+)\]')
INSTRUCTION = (
    "Given a Korean natural-language query, retrieve Korean comic dialogue scenes "
    "that best match the described situation, emotional tone, and dialogue style."
)
HIGH_ANCHORS = [
    "성인 인물들의 감정과 신체 반응이 강하게 고조되어 짧고 다급한 감탄과 반복 대사가 이어지는 장면",
    "성인 인물들의 호흡이 거칠어지고 신음과 외침이 많아지며 상황이 절정에 가까워지는 장면",
    "성인 인물들의 긴장과 쾌감이 최고조에 이르고 대사의 강도와 흥분이 매우 높아진 장면",
]
CALM_ANCHORS = [
    "성인 인물들이 차분하게 일상 대화를 나누며 감정 변화와 격한 반응이 거의 없는 장면",
    "설명과 준비가 중심이고 감탄이나 외침 없이 조용하게 대화하는 장면",
    "상황이 끝난 뒤 안정된 분위기에서 침착하고 느긋하게 대화하는 장면",
]
SMOOTHING_KERNEL = np.asarray([1, 2, 3, 2, 1], dtype=np.float32) / 9


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build one resumable JSONL file containing per-work intensity timelines."
    )
    parser.add_argument("--output-name", default="latest-5000")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--output-file", default=DEFAULT_OUTPUT_FILE)
    parser.add_argument(
        "--embedding-url",
        default=os.environ.get(
            "VIOLET_EMBEDDING_URL", "http://127.0.0.1:8081/v1/embeddings"
        ),
    )
    parser.add_argument("--embedding-model", default=DEFAULT_EMBEDDING_MODEL)
    parser.add_argument("--timeout", type=float, default=300.0)
    parser.add_argument(
        "--workers",
        type=int,
        default=min(32, max(4, os.cpu_count() or 1)),
        help="Concurrent readers/calculators. Default: min(32, CPU count).",
    )
    parser.add_argument(
        "--prefetch",
        type=int,
        default=0,
        help="Maximum queued work items. Default: four times --workers.",
    )
    parser.add_argument("--max-works", type=int, default=None)
    parser.add_argument("--decimals", type=int, default=1)
    parser.add_argument("--peak-count", type=int, default=3)
    parser.add_argument("--peak-distance", type=int, default=6)
    parser.add_argument("--overwrite", action="store_true")
    return parser.parse_args()


def post_json(url: str, payload: dict[str, object], timeout: float) -> dict[str, object]:
    request = Request(
        url,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urlopen(request, timeout=timeout) as response:
            return json.load(response)
    except HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"{url} returned HTTP {error.code}: {detail}") from error
    except URLError as error:
        raise RuntimeError(
            f"Cannot reach embedding server at {url}. Start the embedding container first."
        ) from error


def build_axis_vector(
    embedding_url: str,
    embedding_model: str,
    dimensions: int,
    timeout: float,
) -> np.ndarray:
    prompts = [
        f"Instruct: {INSTRUCTION}\nQuery: {anchor}"
        for anchor in HIGH_ANCHORS + CALM_ANCHORS
    ]
    response = post_json(
        embedding_url,
        {
            "model": embedding_model,
            "input": prompts,
            "encoding_format": "float",
        },
        timeout,
    )
    try:
        vectors = np.asarray(
            [item["embedding"][:dimensions] for item in response["data"]],
            dtype=np.float32,
        )
    except (KeyError, IndexError, TypeError) as error:
        raise RuntimeError(f"Unexpected embedding response: {response!r}") from error
    if vectors.shape != (len(prompts), dimensions):
        raise RuntimeError(
            f"Expected {len(prompts)} anchor vectors with {dimensions} dimensions, "
            f"received {vectors.shape}."
        )
    norms = np.linalg.norm(vectors, axis=1, keepdims=True)
    if not np.all(np.isfinite(norms)) or np.any(norms <= 0):
        raise RuntimeError("Embedding server returned a zero or non-finite anchor vector.")
    vectors /= norms
    return vectors[: len(HIGH_ANCHORS)].mean(axis=0) - vectors[
        len(HIGH_ANCHORS) :
    ].mean(axis=0)


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


def load_page_ids(chunks_path: Path) -> list[list[int]]:
    page_ids: list[list[int]] = []
    with chunks_path.open("rb") as handle:
        for line_number, line in enumerate(handle, start=1):
            match = PAGE_IDS_PATTERN.search(line)
            if match is None:
                raise RuntimeError(
                    f"Missing page_ids in {chunks_path} at line {line_number}"
                )
            page_ids.append([int(value) for value in match.group(1).split(b",")])
    return page_ids


def find_peaks(
    values: np.ndarray, peak_count: int, peak_distance: int, decimals: int
) -> list[list[int | float]]:
    if len(values) < 3 or float(np.ptp(values)) <= 1e-6:
        return []
    candidates = [
        index
        for index in range(1, len(values) - 1)
        if values[index] >= values[index - 1]
        and values[index] >= values[index + 1]
        and (values[index] > values[index - 1] or values[index] > values[index + 1])
    ]
    selected: list[int] = []
    for index in sorted(candidates, key=lambda item: float(values[item]), reverse=True):
        page = index + 1
        if all(abs(page - other_page) >= peak_distance for other_page in selected):
            selected.append(page)
        if len(selected) == peak_count:
            break
    selected.sort()
    return [[page, round(float(values[page - 1]), decimals)] for page in selected]


def contiguous_ranges(indices: np.ndarray) -> list[list[int]]:
    if len(indices) == 0:
        return []
    ranges: list[list[int]] = []
    start = previous = int(indices[0]) + 1
    for zero_based_index in indices[1:]:
        page = int(zero_based_index) + 1
        if page != previous + 1:
            ranges.append([start, previous])
            start = page
        previous = page
    ranges.append([start, previous])
    return ranges


def calculate_work(
    work_dir: Path,
    axis_vector: np.ndarray,
    dimensions: int,
    decimals: int,
    peak_count: int,
    peak_distance: int,
) -> dict[str, object]:
    vectors = np.load(work_dir / "embeddings.npy", allow_pickle=False)
    if vectors.ndim != 2 or vectors.shape[1] != dimensions:
        raise RuntimeError(
            f"Unexpected vector shape for work {work_dir.name}: {vectors.shape}; "
            f"expected (*, {dimensions})"
        )
    page_ids = load_page_ids(work_dir / "chunks.jsonl")
    if len(page_ids) != len(vectors):
        raise RuntimeError(
            f"Chunk/vector mismatch for work {work_dir.name}: "
            f"{len(page_ids)} chunks vs {len(vectors)} vectors"
        )
    if not page_ids:
        return {
            "work_id": int(work_dir.name),
            "page_count": 0,
            "raw": [],
            "smooth": [],
            "peaks": [],
            "status": "no_dialogue_chunks",
        }

    chunk_scores = vectors.astype(np.float32, copy=False) @ axis_vector
    page_count = max(page for pages in page_ids for page in pages)
    sums = np.zeros(page_count, dtype=np.float32)
    counts = np.zeros(page_count, dtype=np.uint16)
    for pages, score in zip(page_ids, chunk_scores, strict=True):
        indices = np.asarray(pages, dtype=np.int32) - 1
        sums[indices] += float(score)
        counts[indices] += 1
    observed = counts > 0
    observed_indices = np.flatnonzero(observed)
    observed_axis = sums[observed] / counts[observed]
    all_indices = np.arange(page_count)
    raw_axis = np.interp(all_indices, observed_indices, observed_axis)
    low, high = np.percentile(observed_axis, [5, 95])
    if high - low <= 1e-9:
        raw = np.zeros(page_count, dtype=np.float32)
    else:
        raw = np.clip((raw_axis - low) / (high - low), 0, 1) * 100
    smooth = np.convolve(
        np.pad(raw, (2, 2), mode="edge"), SMOOTHING_KERNEL, mode="valid"
    )
    result = {
        "work_id": int(work_dir.name),
        "page_count": page_count,
        "raw": [round(float(value), decimals) for value in raw],
        "smooth": [round(float(value), decimals) for value in smooth],
        "peaks": find_peaks(smooth, peak_count, peak_distance, decimals),
    }
    missing_indices = np.flatnonzero(~observed)
    if len(missing_indices):
        result["interpolated_ranges"] = contiguous_ranges(missing_indices)
    return result


def iter_calculated_works(
    work_dirs: list[Path],
    axis_vector: np.ndarray,
    dimensions: int,
    decimals: int,
    peak_count: int,
    peak_distance: int,
    workers: int,
    prefetch: int,
) -> Iterator[dict[str, object]]:
    if workers <= 1:
        for work_dir in work_dirs:
            yield calculate_work(
                work_dir,
                axis_vector,
                dimensions,
                decimals,
                peak_count,
                peak_distance,
            )
        return

    source = iter(work_dirs)
    with ThreadPoolExecutor(
        max_workers=workers, thread_name_prefix="intensity"
    ) as executor:
        pending: dict[Future[dict[str, object]], Path] = {}

        def submit_one() -> bool:
            try:
                work_dir = next(source)
            except StopIteration:
                return False
            future = executor.submit(
                calculate_work,
                work_dir,
                axis_vector,
                dimensions,
                decimals,
                peak_count,
                peak_distance,
            )
            pending[future] = work_dir
            return True

        for _ in range(prefetch):
            if not submit_one():
                break
        while pending:
            completed, _ = wait(pending, return_when=FIRST_COMPLETED)
            for future in completed:
                work_dir = pending.pop(future)
                try:
                    yield future.result()
                except Exception as error:
                    raise RuntimeError(
                        f"Failed to calculate intensity for work {work_dir.name}"
                    ) from error
                submit_one()


def load_partial(path: Path) -> tuple[dict[str, object] | None, set[int]]:
    if not path.exists():
        return None, set()
    metadata = None
    completed: set[int] = set()
    last_valid_offset = 0
    with path.open("rb+") as handle:
        while True:
            line = handle.readline()
            if not line:
                break
            try:
                row = orjson.loads(line)
            except orjson.JSONDecodeError:
                handle.truncate(last_valid_offset)
                break
            last_valid_offset = handle.tell()
            if row.get("type") == "metadata":
                metadata = row
            elif "work_id" in row:
                completed.add(int(row["work_id"]))
    return metadata, completed


def metadata_for(args: argparse.Namespace, dimensions: int) -> dict[str, object]:
    return {
        "type": "metadata",
        "schema_version": SCHEMA_VERSION,
        "method_version": METHOD_VERSION,
        "source_output": args.output_name,
        "model": args.model,
        "embedding_model": args.embedding_model,
        "dimensions": dimensions,
        "score_range": [0, 100],
        "normalization": "within-work percentile 5-95",
        "smoothing_kernel": [1, 2, 3, 2, 1],
        "missing_page_policy": "linear interpolation; nearest value at edges",
        "anchors": {"high": HIGH_ANCHORS, "calm": CALM_ANCHORS},
    }


def validate_partial_metadata(
    existing: dict[str, object] | None, expected: dict[str, object]
) -> None:
    if existing is None:
        raise RuntimeError("Partial output exists but has no metadata row; use --overwrite")
    for key in (
        "schema_version",
        "method_version",
        "source_output",
        "model",
        "embedding_model",
        "dimensions",
    ):
        if existing.get(key) != expected.get(key):
            raise RuntimeError(
                f"Partial output metadata mismatch for {key}: "
                f"{existing.get(key)!r} != {expected.get(key)!r}; use --overwrite"
            )


def main() -> None:
    args = parse_args()
    if args.workers < 1 or args.decimals < 0:
        raise ValueError("--workers must be positive and --decimals must be non-negative")
    if args.peak_count < 0 or args.peak_distance < 1:
        raise ValueError("--peak-count must be non-negative and --peak-distance positive")
    prefetch = args.prefetch or args.workers * 4
    if prefetch < args.workers:
        raise ValueError("--prefetch must be at least --workers")

    output_dir = ROOT / "outputs" / safe_model_name(args.model) / args.output_name
    manifest = load_json(output_dir / "manifest.json")
    dimensions = int(manifest["dimensions"])
    work_dirs = list_work_dirs(output_dir / "works", args.max_works)
    final_path = output_dir / args.output_file
    partial_path = final_path.with_name(f"{final_path.name}.partial")

    if args.overwrite:
        final_path.unlink(missing_ok=True)
        partial_path.unlink(missing_ok=True)
    elif final_path.exists():
        raise FileExistsError(f"Output already exists: {final_path}; pass --overwrite")

    expected_metadata = metadata_for(args, dimensions)
    existing_metadata, completed = load_partial(partial_path)
    if partial_path.exists():
        validate_partial_metadata(existing_metadata, expected_metadata)
    else:
        partial_path.parent.mkdir(parents=True, exist_ok=True)
        with partial_path.open("wb") as handle:
            handle.write(orjson.dumps(expected_metadata, option=orjson.OPT_APPEND_NEWLINE))

    pending_dirs = [path for path in work_dirs if int(path.name) not in completed]
    print(
        f"Selected {len(work_dirs):,} works; resuming after {len(completed):,}, "
        f"pending {len(pending_dirs):,}."
    )
    if not pending_dirs:
        os.replace(partial_path, final_path)
        print(f"Completed output already contained every selected work: {final_path}")
        return

    axis_vector = build_axis_vector(
        args.embedding_url, args.embedding_model, dimensions, args.timeout
    )
    started = time.perf_counter()
    pages_written = 0
    progress = tqdm(
        total=len(work_dirs),
        initial=len(completed),
        desc="Intensity",
        unit="work",
        dynamic_ncols=True,
    )
    try:
        with partial_path.open("ab", buffering=1024 * 1024) as handle:
            results = iter_calculated_works(
                pending_dirs,
                axis_vector,
                dimensions,
                args.decimals,
                args.peak_count,
                args.peak_distance,
                args.workers,
                prefetch,
            )
            for result in results:
                handle.write(orjson.dumps(result, option=orjson.OPT_APPEND_NEWLINE))
                pages_written += int(result["page_count"])
                progress.update(1)
                if progress.n % 250 == 0 or progress.n == progress.total:
                    elapsed = time.perf_counter() - started
                    progress.set_postfix(
                        pages=f"{pages_written:,}",
                        work_s=f"{(progress.n - len(completed)) / max(elapsed, 1e-9):,.0f}",
                        refresh=False,
                    )
                if progress.n % 1_000 == 0:
                    handle.flush()
            handle.flush()
            os.fsync(handle.fileno())
    finally:
        progress.close()

    os.replace(partial_path, final_path)
    elapsed = time.perf_counter() - started
    print(
        f"Wrote {len(work_dirs):,} works to {final_path} in {elapsed:.1f}s "
        f"({len(pending_dirs) / max(elapsed, 1e-9):,.0f} works/s, "
        f"{final_path.stat().st_size / 1_000_000:.1f} MB)."
    )


if __name__ == "__main__":
    main()
