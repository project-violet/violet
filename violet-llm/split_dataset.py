from __future__ import annotations

import argparse
from datetime import datetime, timezone
from pathlib import Path

from tqdm import tqdm

from common import load_json, read_jsonl, write_json, write_jsonl


ROOT = Path(__file__).resolve().parent
DEFAULT_MODEL = "Qwen/Qwen3-Embedding-4B"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Split prepared chunks at dialogue boundaries.")
    parser.add_argument("--source-dataset", default="benchmark-20")
    parser.add_argument("--output-dataset", default="benchmark-20-split384")
    parser.add_argument("--max-chunk-tokens", type=int, default=384)
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--overwrite", action="store_true")
    return parser.parse_args()


def split_row(row: dict[str, object], tokenizer: object, max_tokens: int) -> list[dict[str, object]]:
    dialogues = list(row["dialogues"])
    groups: list[list[dict[str, object]]] = []
    group: list[dict[str, object]] = []
    for dialogue in dialogues:
        candidate = group + [dialogue]
        candidate_text = "\n".join(str(item["text"]) for item in candidate)
        candidate_tokens = len(tokenizer.encode(candidate_text, add_special_tokens=True))
        if group and candidate_tokens > max_tokens:
            groups.append(group)
            group = [dialogue]
        else:
            group = candidate
    if group:
        groups.append(group)

    if len(groups) == 1:
        return [row]
    chunks: list[dict[str, object]] = []
    for part, items in enumerate(groups, 1):
        chunk = dict(row)
        chunk["chunk_id"] = f"{row['chunk_id']}:split-{part}"
        chunk["page_ids"] = sorted({int(item["page"]) for item in items})
        chunk["bubble_count"] = len(items)
        chunk["text"] = "\n".join(str(item["text"]) for item in items)
        chunk["dialogues"] = items
        chunks.append(chunk)
    return chunks


def main() -> None:
    args = parse_args()
    if args.max_chunk_tokens < 1:
        raise ValueError("--max-chunk-tokens must be positive")
    source_dir = ROOT / "data" / args.source_dataset
    output_dir = ROOT / "data" / args.output_dataset
    if output_dir.exists() and not args.overwrite:
        raise FileExistsError(f"Output already exists: {output_dir}")

    from transformers import AutoTokenizer

    tokenizer = AutoTokenizer.from_pretrained(args.model, local_files_only=True)
    source_manifest = load_json(source_dir / "manifest.json")
    output_works: list[dict[str, object]] = []
    original_chunks = 0
    split_chunks = 0
    for summary in tqdm(source_manifest["works"], desc="Splitting", unit="work"):
        work_id = int(summary["work_id"])
        rows = read_jsonl(source_dir / "works" / f"{work_id}.jsonl")
        output_rows: list[dict[str, object]] = []
        for row in rows:
            output_rows.extend(split_row(row, tokenizer, args.max_chunk_tokens))
        write_jsonl(output_dir / "works" / f"{work_id}.jsonl", output_rows)
        original_chunks += len(rows)
        split_chunks += len(output_rows)
        output_summary = dict(summary)
        output_summary["chunk_count"] = len(output_rows)
        output_works.append(output_summary)

    manifest = dict(source_manifest)
    manifest.update(
        {
            "created_at": datetime.now(timezone.utc).isoformat(),
            "parent_dataset": args.source_dataset,
            "split_model": args.model,
            "max_chunk_tokens": args.max_chunk_tokens,
            "works": output_works,
        }
    )
    write_json(output_dir / "manifest.json", manifest)
    print(f"chunks={original_chunks:,}->{split_chunks:,} output={output_dir}")


if __name__ == "__main__":
    main()
