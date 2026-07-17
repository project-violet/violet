from __future__ import annotations

import mmap
import struct
from pathlib import Path
from typing import Any

import numpy as np

from common import load_json


METADATA_HEADER = struct.Struct("<qHI")


class CompactMetadata:
    def __init__(self, index_dir: Path, prefix: str, vector_count: int) -> None:
        manifest = load_json(index_dir / f"{prefix}.json")
        if int(manifest["vector_count"]) != vector_count:
            raise RuntimeError("Compact metadata vector count does not match the index")
        self.vector_count = vector_count
        self.offsets = np.memmap(
            index_dir / str(manifest["offsets_file"]),
            mode="r",
            dtype="<u8",
            shape=(vector_count + 1,),
        )
        self.handle = (index_dir / str(manifest["records_file"])).open("rb")
        self.records = mmap.mmap(self.handle.fileno(), 0, access=mmap.ACCESS_READ)

    def get(self, row_id: int) -> dict[str, Any]:
        if row_id < 0 or row_id >= self.vector_count:
            raise IndexError(f"Metadata row is out of range: {row_id}")
        start = int(self.offsets[row_id])
        end = int(self.offsets[row_id + 1])
        work_id, page_count, text_length = METADATA_HEADER.unpack_from(
            self.records, start
        )
        pages_start = start + METADATA_HEADER.size
        pages_end = pages_start + page_count * 4
        text_end = pages_end + text_length
        if text_end != end:
            raise RuntimeError(f"Invalid compact metadata record at row {row_id}")
        pages = np.frombuffer(
            self.records, dtype="<i4", count=page_count, offset=pages_start
        ).astype(np.int64).tolist()
        text = self.records[pages_end:text_end].decode("utf-8")
        return {"work_id": int(work_id), "page_ids": pages, "text": text}

    def close(self) -> None:
        self.records.close()
        self.handle.close()
        mmap_handle = getattr(self.offsets, "_mmap", None)
        if mmap_handle is not None:
            mmap_handle.close()


class AcceleratedSearchIndex:
    def __init__(
        self,
        index_dir: Path,
        vector_count: int,
        dimensions: int,
        threads: int,
        faiss_name: str = "faiss-sq8.index",
        metadata_prefix: str = "compact-metadata",
    ) -> None:
        try:
            import faiss
        except ImportError as error:
            raise RuntimeError(
                "FAISS is required for the accelerated search index"
            ) from error

        faiss.omp_set_num_threads(threads)
        self.index = faiss.read_index(str(index_dir / faiss_name))
        if int(self.index.ntotal) != vector_count:
            raise RuntimeError("FAISS vector count does not match the base index")
        if int(self.index.d) != dimensions:
            raise RuntimeError("FAISS dimensions do not match the base index")
        self.metadata = CompactMetadata(index_dir, metadata_prefix, vector_count)

    def search(self, query: np.ndarray, candidate_k: int) -> list[tuple[float, int]]:
        scores, row_ids = self.index.search(
            np.ascontiguousarray(query.reshape(1, -1), dtype=np.float32), candidate_k
        )
        return [
            (float(score), int(row_id))
            for score, row_id in zip(scores[0], row_ids[0])
            if row_id >= 0
        ]

    def get(self, row_id: int) -> dict[str, Any]:
        return self.metadata.get(row_id)

    def close(self) -> None:
        self.metadata.close()
