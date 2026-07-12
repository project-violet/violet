from __future__ import annotations

import argparse
import heapq
import json
import sys
from pathlib import Path

import numpy as np

from common import load_json, read_jsonl, safe_model_name


ROOT = Path(__file__).resolve().parent
DEFAULT_MODEL = "Qwen/Qwen3-Embedding-4B"
INSTRUCTION = (
    "Given a Korean natural-language query, retrieve Korean comic dialogue scenes "
    "that best match the described situation, emotional tone, and dialogue style."
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Search local scene embeddings.")
    parser.add_argument("query")
    parser.add_argument("--output-name", default="latest-1000")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--top-k", type=int, default=20)
    parser.add_argument("--device")
    parser.add_argument("--json", action="store_true", dest="as_json")
    return parser.parse_args()


def main() -> None:
    # OCR can contain characters outside the legacy Windows cp949 code page.
    # Keep search output usable from a standard PowerShell console.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    args = parse_args()
    output_dir = ROOT / "outputs" / safe_model_name(args.model) / args.output_name
    manifest = load_json(output_dir / "manifest.json")

    import torch
    from sentence_transformers import SentenceTransformer

    device = args.device or ("cuda" if torch.cuda.is_available() else "cpu")
    model = SentenceTransformer(
        args.model,
        device=device,
        model_kwargs={"torch_dtype": torch.float16 if device != "cpu" else torch.float32},
        tokenizer_kwargs={"padding_side": "left"},
    )
    model.max_seq_length = int(manifest["max_length"])
    prompt = f"Instruct: {INSTRUCTION}\nQuery: {args.query}"
    query = model.encode([prompt], normalize_embeddings=True, convert_to_numpy=True)[0]
    query = query[: int(manifest["dimensions"])].astype(np.float32)
    query /= np.linalg.norm(query)

    heap: list[tuple[float, int, dict[str, object]]] = []
    serial = 0
    for work_dir in (output_dir / "works").iterdir():
        if not work_dir.is_dir() or work_dir.name.startswith("."):
            continue
        vectors = np.load(work_dir / "embeddings.npy", mmap_mode="r", allow_pickle=False)
        scores = np.asarray(vectors, dtype=np.float32) @ query
        count = min(args.top_k, len(scores))
        if not count:
            continue
        rows = read_jsonl(work_dir / "chunks.jsonl")
        for index in np.argpartition(scores, len(scores) - count)[-count:]:
            item = (float(scores[index]), serial, rows[int(index)])
            serial += 1
            if len(heap) < args.top_k:
                heapq.heappush(heap, item)
            elif item[0] > heap[0][0]:
                heapq.heapreplace(heap, item)

    results = [
        {"rank": rank, "score": score, **row}
        for rank, (score, _, row) in enumerate(sorted(heap, reverse=True), 1)
    ]
    if args.as_json:
        print(json.dumps(results, ensure_ascii=False, indent=2))
        return
    for result in results:
        print(f"[{result['rank']:02d}] score={result['score']:.4f} work={result['work_id']} pages={result['page_ids']}")
        print(result["text"].replace("\n", " / ")[:500])
        print()


if __name__ == "__main__":
    main()
