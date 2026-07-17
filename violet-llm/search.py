from __future__ import annotations

import argparse
import heapq
import json
import os
import sys
import time
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit, urlunsplit
from urllib.request import Request, urlopen

import numpy as np

from common import load_json, read_jsonl, safe_model_name


ROOT = Path(__file__).resolve().parent
DEFAULT_INDEX_MODEL = "Qwen/Qwen3-Embedding-4B"
DEFAULT_EMBEDDING_MODEL = "Qwen/Qwen3-Embedding-4B-GGUF:Q5_K_M"
DEFAULT_RERANKER_MODEL = "Qwen/Qwen3-Reranker-0.6B"
INSTRUCTION = (
    "Given a Korean natural-language query, retrieve Korean comic dialogue scenes "
    "that best match the described situation, emotional tone, and dialogue style."
)
LOCATION_DTYPE = np.dtype([("work_id", "<i8"), ("chunk_index", "<i4")])
DEFAULT_INDEX_BLOCK_ROWS = 32_768


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Search with Qwen3 4B embeddings and a Qwen3 reranker.")
    parser.add_argument("query")
    parser.add_argument("--output-name", default="latest-5000")
    parser.add_argument("--index-name", default="index")
    parser.add_argument("--index-block-rows", type=int, default=DEFAULT_INDEX_BLOCK_ROWS)
    parser.add_argument(
        "--model",
        default=DEFAULT_INDEX_MODEL,
        help="Model name used to locate the existing embedding index.",
    )
    parser.add_argument("--top-k", type=int, default=20)
    parser.add_argument("--candidate-k", type=int, default=100)
    parser.add_argument(
        "--embedding-url",
        default=os.environ.get("VIOLET_EMBEDDING_URL", "http://127.0.0.1:8081/v1/embeddings"),
    )
    parser.add_argument(
        "--reranker-url",
        default=os.environ.get("VIOLET_RERANKER_URL", "http://127.0.0.1:8082/v1/rerank"),
    )
    parser.add_argument("--embedding-model", default=DEFAULT_EMBEDDING_MODEL)
    parser.add_argument(
        "--reranker-model",
        default=os.environ.get("VIOLET_RERANKER_MODEL", DEFAULT_RERANKER_MODEL),
    )
    parser.add_argument(
        "--reranker-separate-instruction",
        action=argparse.BooleanOptionalAction,
        default=None,
        help="Send the task instruction through the vLLM rerank API instruction field.",
    )
    parser.add_argument("--timeout", type=float, default=300.0)
    parser.add_argument("--no-rerank", action="store_true")
    parser.add_argument("--json", action="store_true", dest="as_json")
    args = parser.parse_args()
    if args.reranker_separate_instruction is None:
        args.reranker_separate_instruction = (
            args.reranker_model == DEFAULT_RERANKER_MODEL
        )
    return args


def post_json(url: str, payload: dict[str, Any], timeout: float) -> Any:
    request = Request(
        url,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"{url} returned HTTP {error.code}: {detail}") from error
    except URLError as error:
        raise RuntimeError(
            f"Cannot reach {url}. Start the Docker model services with "
            "`docker compose up -d embedding-llama reranker-vllm` first."
        ) from error


def health_url(url: str) -> str:
    parts = urlsplit(url)
    return urlunsplit((parts.scheme, parts.netloc, "/health", "", ""))


def server_is_ready(url: str) -> bool:
    try:
        with urlopen(health_url(url), timeout=1.0) as response:
            return response.status == 200
    except (HTTPError, URLError, TimeoutError):
        return False


def ensure_servers(args: argparse.Namespace) -> None:
    embedding_ready = server_is_ready(args.embedding_url)
    reranker_ready = args.no_rerank or server_is_ready(args.reranker_url)
    if embedding_ready and reranker_ready:
        return
    missing = []
    if not embedding_ready:
        missing.append(f"embedding ({args.embedding_url})")
    if not reranker_ready:
        missing.append(f"reranker ({args.reranker_url})")
    raise RuntimeError(
        f"Search model services are not ready: {', '.join(missing)}. "
        "From the repository root, run "
        "`docker compose up -d embedding-llama reranker-vllm`."
    )


def embed_query(args: argparse.Namespace, dimensions: int) -> np.ndarray:
    prompt = f"Instruct: {INSTRUCTION}\nQuery: {args.query}"
    response = post_json(
        args.embedding_url,
        {
            "model": args.embedding_model,
            "input": [prompt],
            "encoding_format": "float",
        },
        args.timeout,
    )
    try:
        vector = np.asarray(response["data"][0]["embedding"], dtype=np.float32)
    except (KeyError, IndexError, TypeError) as error:
        raise RuntimeError(f"Unexpected embedding response: {response!r}") from error
    if vector.size < dimensions:
        raise RuntimeError(
            f"Embedding server returned {vector.size} dimensions, but the index needs {dimensions}."
        )
    vector = vector[:dimensions]
    norm = float(np.linalg.norm(vector))
    if not np.isfinite(norm) or norm <= 0:
        raise RuntimeError("Embedding server returned a zero or non-finite query vector.")
    return vector / norm


def top_indices(scores: np.ndarray, count: int) -> np.ndarray:
    if count >= len(scores):
        return np.arange(len(scores))
    return np.argpartition(scores, len(scores) - count)[-count:]


def retrieve_legacy_candidates(
    output_dir: Path,
    query: np.ndarray,
    candidate_k: int,
) -> list[dict[str, Any]]:
    heap: list[tuple[float, int, Path, int]] = []
    serial = 0
    for work_dir in (output_dir / "works").iterdir():
        if not work_dir.is_dir() or work_dir.name.startswith("."):
            continue
        vectors = np.load(work_dir / "embeddings.npy", mmap_mode="r", allow_pickle=False)
        scores = np.asarray(vectors, dtype=np.float32) @ query
        count = min(candidate_k, len(scores))
        if not count:
            continue
        indices = top_indices(scores, count)
        for index in indices:
            item = (float(scores[index]), serial, work_dir, int(index))
            serial += 1
            if len(heap) < candidate_k:
                heapq.heappush(heap, item)
            elif item[0] > heap[0][0]:
                heapq.heapreplace(heap, item)

    rows_cache: dict[Path, list[dict[str, Any]]] = {}
    results: list[dict[str, Any]] = []
    for score, _, work_dir, index in sorted(heap, reverse=True):
        rows = rows_cache.get(work_dir)
        if rows is None:
            rows = read_jsonl(work_dir / "chunks.jsonl")
            rows_cache[work_dir] = rows
        results.append({"embedding_score": score, **rows[index]})
    return results


def retrieve_index_candidates(
    output_dir: Path,
    index_dir: Path,
    query: np.ndarray,
    candidate_k: int,
    block_rows: int,
) -> list[dict[str, Any]]:
    manifest = load_json(index_dir / "manifest.json")
    dimensions = int(manifest["dimensions"])
    if dimensions != query.size:
        raise RuntimeError(
            f"Search index has {dimensions} dimensions, but query has {query.size}"
        )
    vector_count = int(manifest["vector_count"])
    storage_dtype = np.dtype(str(manifest["storage_dtype"]))
    locations = np.memmap(
        index_dir / "locations.bin",
        mode="r",
        dtype=LOCATION_DTYPE,
        shape=(vector_count,),
    )

    heap: list[tuple[float, int]] = []
    for shard in manifest["shards"]:
        shard_start = int(shard["start"])
        shard_count = int(shard["count"])
        vectors = np.memmap(
            index_dir / str(shard["file"]),
            mode="r",
            dtype=storage_dtype,
            shape=(shard_count, dimensions),
        )
        for block_start in range(0, shard_count, block_rows):
            block_end = min(block_start + block_rows, shard_count)
            block = np.asarray(vectors[block_start:block_end], dtype=np.float32)
            scores = block @ query
            count = min(candidate_k, len(scores))
            for index in top_indices(scores, count):
                row_id = shard_start + block_start + int(index)
                item = (float(scores[index]), row_id)
                if len(heap) < candidate_k:
                    heapq.heappush(heap, item)
                elif item[0] > heap[0][0]:
                    heapq.heapreplace(heap, item)

    rows_cache: dict[int, list[dict[str, Any]]] = {}
    results: list[dict[str, Any]] = []
    for score, row_id in sorted(heap, reverse=True):
        location = locations[row_id]
        work_id = int(location["work_id"])
        chunk_index = int(location["chunk_index"])
        rows = rows_cache.get(work_id)
        if rows is None:
            rows = read_jsonl(output_dir / "works" / str(work_id) / "chunks.jsonl")
            rows_cache[work_id] = rows
        if chunk_index >= len(rows):
            raise RuntimeError(
                f"Index row {row_id} points past work {work_id} chunks: {chunk_index}"
            )
        results.append({"embedding_score": score, **rows[chunk_index]})
    return results


def retrieve_candidates(
    output_dir: Path,
    index_name: str,
    query: np.ndarray,
    candidate_k: int,
    block_rows: int,
) -> list[dict[str, Any]]:
    index_dir = output_dir / index_name
    if (index_dir / "manifest.json").is_file():
        manifest = load_json(index_dir / "manifest.json")
        print(
            f"Searching consolidated index: {int(manifest['vector_count']):,} vectors "
            f"in {len(manifest['shards']):,} shards, window=3...",
            file=sys.stderr,
        )
        return retrieve_index_candidates(
            output_dir, index_dir, query, candidate_k, block_rows
        )
    print(
        f"Consolidated index not found at {index_dir}; scanning per-work files. "
        f"Run: python build_index.py --output-name {output_dir.name}",
        file=sys.stderr,
    )
    return retrieve_legacy_candidates(output_dir, query, candidate_k)


def parse_reranker_results(response: Any) -> list[dict[str, Any]]:
    if isinstance(response, dict):
        items = response.get("results", response.get("data"))
    else:
        items = response
    if not isinstance(items, list):
        raise RuntimeError(f"Unexpected reranker response: {response!r}")

    parsed: list[dict[str, Any]] = []
    for item in items:
        if not isinstance(item, dict) or "index" not in item:
            raise RuntimeError(f"Unexpected reranker result: {item!r}")
        score = item.get("relevance_score", item.get("score"))
        if score is None:
            raise RuntimeError(f"Reranker result has no score: {item!r}")
        parsed.append({"index": int(item["index"]), "rerank_score": float(score)})
    return parsed


def rerank_candidates(
    args: argparse.Namespace,
    candidates: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    if args.no_rerank:
        return [
            {"rank": rank, "score": row["embedding_score"], "rerank_score": None, **row}
            for rank, row in enumerate(candidates[: args.top_k], 1)
        ]

    query = (
        args.query
        if args.reranker_separate_instruction
        else f"Instruct: {INSTRUCTION}\nQuery: {args.query}"
    )
    payload: dict[str, Any] = {
        "model": args.reranker_model,
        "query": query,
        "documents": [str(row["text"]) for row in candidates],
        "top_n": min(args.top_k, len(candidates)),
    }
    if args.reranker_separate_instruction:
        payload["instruction"] = INSTRUCTION
    response = post_json(
        args.reranker_url,
        payload,
        args.timeout,
    )
    ranked = parse_reranker_results(response)
    results: list[dict[str, Any]] = []
    for rank, item in enumerate(ranked[: args.top_k], 1):
        index = item["index"]
        if index < 0 or index >= len(candidates):
            raise RuntimeError(f"Reranker returned invalid document index {index}.")
        row = candidates[index]
        results.append(
            {
                "rank": rank,
                "score": item["rerank_score"],
                "rerank_score": item["rerank_score"],
                **row,
            }
        )
    return results


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    args = parse_args()
    if args.top_k < 1 or args.candidate_k < args.top_k:
        raise ValueError("--top-k must be positive and --candidate-k must be at least --top-k.")
    if args.index_block_rows < 1:
        raise ValueError("--index-block-rows must be positive")

    output_dir = ROOT / "outputs" / safe_model_name(args.model) / args.output_name
    manifest = load_json(output_dir / "manifest.json")
    dimensions = int(manifest["dimensions"])
    ensure_servers(args)
    query = embed_query(args, dimensions)
    retrieval_started = time.perf_counter()
    candidates = retrieve_candidates(
        output_dir,
        args.index_name,
        query,
        args.candidate_k,
        args.index_block_rows,
    )
    print(
        f"Retrieved {len(candidates):,} candidates in "
        f"{time.perf_counter() - retrieval_started:.2f}s.",
        file=sys.stderr,
    )
    results = rerank_candidates(args, candidates)

    if args.as_json:
        print(json.dumps(results, ensure_ascii=False, indent=2))
        return
    for result in results:
        rerank = result["rerank_score"]
        score_text = (
            f"rerank={rerank:.4f} embed={result['embedding_score']:.4f}"
            if rerank is not None
            else f"embed={result['embedding_score']:.4f}"
        )
        print(
            f"[{result['rank']:02d}] {score_text} "
            f"work={result['work_id']} pages={result['page_ids']}"
        )
        print(str(result["text"]).replace("\n", " / ")[:500])
        print()


if __name__ == "__main__":
    main()
