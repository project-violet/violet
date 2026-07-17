from __future__ import annotations

import argparse
import shutil
from datetime import datetime, timezone
from pathlib import Path

from tqdm import tqdm

from common import latest_works, make_chunks, write_json, write_jsonl


ROOT = Path(__file__).resolve().parent
DEFAULT_RAW_DIR = ROOT.parent / "violet-ocr" / "raw-merged-v2"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Prepare latest raw-merged-v2 works for embedding.")
    parser.add_argument("--input-dir", type=Path, default=DEFAULT_RAW_DIR)
    parser.add_argument("--work-count", type=int, default=10000)
    parser.add_argument("--dataset-name", default="latest-5000")
    parser.add_argument("--window-pages", type=int, default=3)
    parser.add_argument("--stride-pages", type=int, default=2)
    parser.add_argument("--overwrite", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    works = latest_works(args.input_dir.resolve(), args.work_count)
    target = ROOT / "data" / args.dataset_name
    if target.exists():
        if not args.overwrite:
            raise SystemExit(f"{target} already exists; rerun with --overwrite")
        shutil.rmtree(target)
    (target / "works").mkdir(parents=True)

    summaries = []
    for work in tqdm(works, desc="Preparing", unit="work"):
        chunks = make_chunks(work, args.window_pages, args.stride_pages)
        write_jsonl(target / "works" / f"{work.work_id}.jsonl", chunks)
        summaries.append(
            {
                "work_id": work.work_id,
                "source_file": str(work.path),
                "chunk_count": len(chunks),
                "bubble_count": sum(chunk["bubble_count"] for chunk in chunks),
            }
        )

    write_json(
        target / "manifest.json",
        {
            "schema_version": 1,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "selection": "numeric filename descending",
            "work_ids": [work.work_id for work in works],
            "window_pages": args.window_pages,
            "stride_pages": args.stride_pages,
            "works": summaries,
        },
    )
    print(f"Prepared {len(works)} works / {sum(item['chunk_count'] for item in summaries)} chunks")
    print(f"ID range: {works[0].work_id} .. {works[-1].work_id}")


if __name__ == "__main__":
    main()
