from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

try:
    import orjson
except ImportError:
    orjson = None


@dataclass(frozen=True)
class Work:
    work_id: int
    path: Path


def load_json(path: Path) -> Any:
    data = path.read_bytes()
    return orjson.loads(data) if orjson else json.loads(data.decode("utf-8-sig"))


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def write_jsonl(path: Path, rows: Iterable[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8", newline="\n") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n")
    os.replace(temporary, path)


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    with path.open("r", encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]


def latest_works(raw_dir: Path, count: int) -> list[Work]:
    works = [Work(int(path.stem), path.resolve()) for path in raw_dir.glob("*.json") if path.stem.isdigit()]
    works.sort(key=lambda work: work.work_id, reverse=True)
    if len(works) < count:
        raise RuntimeError(f"Only {len(works)} numeric JSON files found; requested {count}")
    return works[:count]


def make_chunks(work: Work, window_pages: int, stride_pages: int) -> list[dict[str, Any]]:
    pages = sorted(load_json(work.path)["pages"], key=lambda page: int(page["page"]))
    chunks: list[dict[str, Any]] = []
    for start in range(0, len(pages), stride_pages):
        window = pages[start : start + window_pages]
        dialogues: list[dict[str, Any]] = []
        text_parts: list[str] = []
        for page in window:
            page_number = int(page["page"])
            for dialogue_index, dialogue in enumerate(page["dialogues"]):
                text = " ".join(str(dialogue["text"]).replace("\u3000", " ").split())
                if not text:
                    continue
                text_parts.append(text)
                dialogues.append(
                    {
                        "page": page_number,
                        "dialogue_index": dialogue_index,
                        "text": text,
                        "confidence": dialogue.get("confidence"),
                        "bbox": dialogue.get("bbox"),
                    }
                )
        if text_parts:
            page_ids = [int(page["page"]) for page in window]
            chunks.append(
                {
                    "chunk_id": f"{work.work_id}:{page_ids[0]}-{page_ids[-1]}",
                    "work_id": work.work_id,
                    "source_file": str(work.path),
                    "page_ids": page_ids,
                    "bubble_count": len(dialogues),
                    "text": "\n".join(text_parts),
                    "dialogues": dialogues,
                }
            )
        if start + window_pages >= len(pages):
            break
    return chunks


def safe_model_name(model: str) -> str:
    return model.replace("/", "--").replace("\\", "--")

