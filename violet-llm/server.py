from __future__ import annotations

import asyncio
import heapq
import os
import time
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any

import numpy as np
from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel, Field, model_validator

from common import load_json, read_jsonl, safe_model_name
from search import (
    DEFAULT_EMBEDDING_MODEL,
    DEFAULT_INDEX_BLOCK_ROWS,
    DEFAULT_INDEX_MODEL,
    DEFAULT_RERANKER_MODEL,
    INSTRUCTION,
    LOCATION_DTYPE,
    parse_reranker_results,
    post_json,
)


ROOT = Path(__file__).resolve().parent


def env_int(name: str, default: int) -> int:
    value = int(os.environ.get(name, default))
    if value < 1:
        raise ValueError(f"{name} must be positive")
    return value


def env_bool(name: str, default: bool = False) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


class SearchRequest(BaseModel):
    query: str = Field(min_length=1, max_length=500)
    candidate_k: int = Field(default=500, ge=1)
    top_k: int = Field(default=10, ge=1)
    rerank: bool = True
    include_messages: bool = False

    @model_validator(mode="after")
    def validate_counts(self) -> "SearchRequest":
        if self.candidate_k < self.top_k:
            raise ValueError("candidate_k must be at least top_k")
        return self


class SearchEngine:
    def __init__(self) -> None:
        output_root = Path(os.environ.get("VIOLET_LLM_OUTPUT_ROOT", ROOT / "outputs"))
        self.model = os.environ.get("VIOLET_LLM_INDEX_MODEL", DEFAULT_INDEX_MODEL)
        self.output_name = os.environ.get("VIOLET_LLM_OUTPUT_NAME", "latest-5000")
        self.index_name = os.environ.get("VIOLET_LLM_INDEX_NAME", "index")
        self.output_dir = output_root / safe_model_name(self.model) / self.output_name
        self.index_dir = self.output_dir / self.index_name
        self.block_rows = env_int("VIOLET_LLM_INDEX_BLOCK_ROWS", DEFAULT_INDEX_BLOCK_ROWS)
        self.max_candidate_k = env_int("VIOLET_LLM_MAX_CANDIDATE_K", 1000)
        self.max_top_k = env_int("VIOLET_LLM_MAX_TOP_K", 100)
        self.timeout = float(os.environ.get("VIOLET_LLM_MODEL_TIMEOUT", "300"))
        self.embedding_url = os.environ.get(
            "VIOLET_EMBEDDING_URL", "http://127.0.0.1:8081/v1/embeddings"
        )
        self.reranker_url = os.environ.get(
            "VIOLET_RERANKER_URL", "http://127.0.0.1:8082/v1/rerank"
        )
        self.embedding_model = os.environ.get(
            "VIOLET_EMBEDDING_MODEL", DEFAULT_EMBEDDING_MODEL
        )
        self.reranker_model = os.environ.get(
            "VIOLET_RERANKER_MODEL", DEFAULT_RERANKER_MODEL
        )
        self.reranker_separate_instruction = env_bool(
            "VIOLET_RERANKER_SEPARATE_INSTRUCTION"
        )

        manifest_path = self.index_dir / "manifest.json"
        if not manifest_path.is_file():
            raise FileNotFoundError(
                f"Consolidated index is missing: {manifest_path}. "
                f"Run build_index.py --output-name {self.output_name} first."
            )
        self.manifest = load_json(manifest_path)
        self.dimensions = int(self.manifest["dimensions"])
        self.vector_count = int(self.manifest["vector_count"])
        self.work_count = int(self.manifest["work_count"])
        self.storage_dtype = np.dtype(str(self.manifest["storage_dtype"]))
        self.locations = np.memmap(
            self.index_dir / "locations.bin",
            mode="r",
            dtype=LOCATION_DTYPE,
            shape=(self.vector_count,),
        )
        self.shards: list[tuple[int, int, np.memmap]] = []
        for shard in self.manifest["shards"]:
            start = int(shard["start"])
            count = int(shard["count"])
            vectors = np.memmap(
                self.index_dir / str(shard["file"]),
                mode="r",
                dtype=self.storage_dtype,
                shape=(count, self.dimensions),
            )
            self.shards.append((start, count, vectors))

    def embed_query(self, query: str) -> np.ndarray:
        prompt = f"Instruct: {INSTRUCTION}\nQuery: {query}"
        response = post_json(
            self.embedding_url,
            {
                "model": self.embedding_model,
                "input": [prompt],
                "encoding_format": "float",
            },
            self.timeout,
        )
        try:
            vector = np.asarray(response["data"][0]["embedding"], dtype=np.float32)
        except (KeyError, IndexError, TypeError) as error:
            raise RuntimeError(f"Unexpected embedding response: {response!r}") from error
        if vector.size < self.dimensions:
            raise RuntimeError(
                f"Embedding server returned {vector.size} dimensions; "
                f"the index needs {self.dimensions}."
            )
        vector = vector[: self.dimensions]
        norm = float(np.linalg.norm(vector))
        if not np.isfinite(norm) or norm <= 0:
            raise RuntimeError("Embedding server returned a zero or non-finite vector")
        return vector / norm

    def retrieve_refs(self, query: np.ndarray, candidate_k: int) -> list[tuple[float, int]]:
        heap: list[tuple[float, int]] = []
        for shard_start, shard_count, vectors in self.shards:
            for block_start in range(0, shard_count, self.block_rows):
                block_end = min(block_start + self.block_rows, shard_count)
                block = np.asarray(vectors[block_start:block_end], dtype=np.float32)
                scores = block @ query
                count = min(candidate_k, len(scores))
                if count >= len(scores):
                    indices = np.arange(len(scores))
                else:
                    indices = np.argpartition(scores, len(scores) - count)[-count:]
                for index in indices:
                    row_id = shard_start + block_start + int(index)
                    item = (float(scores[index]), row_id)
                    if len(heap) < candidate_k:
                        heapq.heappush(heap, item)
                    elif item[0] > heap[0][0]:
                        heapq.heapreplace(heap, item)
        return sorted(heap, reverse=True)

    def materialize(
        self, refs: list[tuple[float, int]]
    ) -> list[dict[str, Any]]:
        rows_cache: dict[int, list[dict[str, Any]]] = {}
        candidates: list[dict[str, Any]] = []
        for embedding_score, row_id in refs:
            location = self.locations[row_id]
            work_id = int(location["work_id"])
            chunk_index = int(location["chunk_index"])
            rows = rows_cache.get(work_id)
            if rows is None:
                rows = read_jsonl(self.output_dir / "works" / str(work_id) / "chunks.jsonl")
                rows_cache[work_id] = rows
            if chunk_index >= len(rows):
                raise RuntimeError(
                    f"Index row {row_id} points past work {work_id} chunks: {chunk_index}"
                )
            candidates.append({"embedding_score": embedding_score, **rows[chunk_index]})
        return candidates

    def format_result(
        self,
        row: dict[str, Any],
        rank: int,
        rerank_score: float | None,
        include_messages: bool,
    ) -> dict[str, Any]:
        result: dict[str, Any] = {
            "rank": rank,
            "rerank_score": rerank_score,
            "embed_score": float(row["embedding_score"]),
            "work": int(row["work_id"]),
            "pages": [int(page) for page in row["page_ids"]],
        }
        if include_messages:
            result["messages"] = str(row["text"])
        return result

    def search(self, request: SearchRequest) -> dict[str, Any]:
        if request.candidate_k > self.max_candidate_k:
            raise ValueError(f"candidate_k cannot exceed {self.max_candidate_k}")
        if request.top_k > self.max_top_k:
            raise ValueError(f"top_k cannot exceed {self.max_top_k}")

        started = time.perf_counter()
        query_vector = self.embed_query(request.query)
        refs = self.retrieve_refs(query_vector, request.candidate_k)

        results: list[dict[str, Any]] = []
        if request.rerank:
            candidates = self.materialize(refs)
            reranker_query = (
                request.query
                if self.reranker_separate_instruction
                else f"Instruct: {INSTRUCTION}\nQuery: {request.query}"
            )
            reranker_payload: dict[str, Any] = {
                "model": self.reranker_model,
                "query": reranker_query,
                "documents": [str(row["text"]) for row in candidates],
                "top_n": min(request.top_k, len(candidates)),
            }
            if self.reranker_separate_instruction:
                reranker_payload["instruction"] = INSTRUCTION
            response = post_json(
                self.reranker_url,
                reranker_payload,
                self.timeout,
            )
            ranked = parse_reranker_results(response)
            for rank, item in enumerate(ranked[: request.top_k], 1):
                index = int(item["index"])
                if index < 0 or index >= len(candidates):
                    raise RuntimeError(f"Reranker returned invalid index {index}")
                results.append(
                    self.format_result(
                        candidates[index],
                        rank,
                        float(item["rerank_score"]),
                        request.include_messages,
                    )
                )
        else:
            candidates = self.materialize(refs[: request.top_k])
            for rank, row in enumerate(candidates, 1):
                results.append(
                    self.format_result(row, rank, None, request.include_messages)
                )

        return {
            "elapsed_ms": round((time.perf_counter() - started) * 1000, 2),
            "results": results,
        }

    def close(self) -> None:
        mappings = [self.locations, *(vectors for _, _, vectors in self.shards)]
        for mapping in mappings:
            mmap = getattr(mapping, "_mmap", None)
            if mmap is not None:
                mmap.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    engine = SearchEngine()
    app.state.engine = engine
    app.state.search_slots = asyncio.Semaphore(env_int("VIOLET_LLM_SEARCH_CONCURRENCY", 1))
    try:
        yield
    finally:
        engine.close()


app = FastAPI(
    title="Violet LLM Search API",
    version="0.1.0",
    lifespan=lifespan,
)


@app.get("/health")
async def health(request: Request) -> dict[str, Any]:
    engine: SearchEngine = request.app.state.engine
    return {
        "status": "ok",
        "output": engine.output_name,
        "works": engine.work_count,
        "vectors": engine.vector_count,
        "dimensions": engine.dimensions,
    }


@app.post("/v1/search")
async def search(payload: SearchRequest, request: Request) -> dict[str, Any]:
    engine: SearchEngine = request.app.state.engine
    semaphore: asyncio.Semaphore = request.app.state.search_slots
    try:
        async with semaphore:
            return await asyncio.to_thread(engine.search, payload)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
