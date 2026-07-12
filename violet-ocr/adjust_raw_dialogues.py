from __future__ import annotations

import argparse
import copy
import json
import os
from pathlib import Path


def _geometry(item: dict) -> tuple[float, float, float, float, float, float]:
    x1, y1, x2, y2 = item["bbox"]
    return x1, y1, x2, y2, max(1, x2 - x1), max(1, y2 - y1)


def _is_credit_like(text: str) -> bool:
    compact = "".join(text.split())
    return len(compact) <= 12 and "/" in compact


def _dominant_script(text: str) -> str | None:
    hangul = sum("가" <= char <= "힣" for char in text)
    latin = sum(char.isascii() and char.isalpha() for char in text)
    if hangul >= max(2, latin * 2):
        return "hangul"
    if latin >= max(2, hangul * 2):
        return "latin"
    return None


def _pair_score(a: dict, b: dict) -> tuple[float, str] | None:
    a_sources = a.get("mergeMeta", {}).get("sourceDialogueIndices", [a["_sourceIndex"]])
    b_sources = b.get("mergeMeta", {}).get("sourceDialogueIndices", [b["_sourceIndex"]])
    if len(set(a_sources + b_sources)) > 4:
        return None
    if _is_credit_like(str(a.get("text", ""))) or _is_credit_like(str(b.get("text", ""))):
        return None
    a_script = _dominant_script(str(a.get("text", "")))
    b_script = _dominant_script(str(b.get("text", "")))
    if a_script is not None and b_script is not None and a_script != b_script:
        return None

    ax1, ay1, ax2, ay2, aw, ah = _geometry(a)
    bx1, by1, bx2, by2, bw, bh = _geometry(b)
    intersection_width = max(0, min(ax2, bx2) - max(ax1, bx1))
    intersection_height = max(0, min(ay2, by2) - max(ay1, by1))
    intersection_ratio = (intersection_width * intersection_height) / min(aw * ah, bw * bh)
    if intersection_ratio >= 0.5:
        return None

    size_ratio = max(ah, bh) / min(ah, bh)
    if size_ratio > 1.8:
        return None

    y_overlap = max(0, min(ay2, by2) - max(ay1, by1)) / min(ah, bh)
    x_gap = max(0, max(ax1, bx1) - min(ax2, bx2))
    terminal = ".!?。！？…~"
    if (
        y_overlap >= 0.85
        and x_gap <= 0.1 * min(ah, bh)
        and aw / ah >= 2.5
        and bw / bh >= 2.5
        and not str(a.get("text", "")).rstrip().endswith(tuple(terminal))
        and not str(b.get("text", "")).rstrip().endswith(tuple(terminal))
    ):
        return 3.0 + y_overlap - x_gap / max(ah, bh), "same-line"

    upper, lower = (a, b) if ay1 <= by1 else (b, a)
    ux1, uy1, ux2, uy2, uw, uh = _geometry(upper)
    lx1, ly1, lx2, ly2, lw, lh = _geometry(lower)
    vertical_gap = max(0, ly1 - uy2)
    x_overlap = max(0, min(ux2, lx2) - max(ux1, lx1)) / min(uw, lw)
    center_delta = abs((ux1 + ux2) / 2 - (lx1 + lx2) / 2)
    aligned = x_overlap >= 0.75 and center_delta <= 0.1 * max(uw, lw)
    upper_ends_sentence = str(upper.get("text", "")).rstrip().endswith(tuple(terminal))
    upper_length = len("".join(str(upper.get("text", "")).split()))
    lower_length = len("".join(str(lower.get("text", "")).split()))
    both_are_long_blocks = upper_length > 20 and lower_length > 20
    if aligned and not upper_ends_sentence and not both_are_long_blocks and vertical_gap <= 0.25 * min(uh, lh):
        return 2.0 + x_overlap - vertical_gap / max(uh, lh), "stacked-lines"
    return None


def _merge_pair(a: dict, b: dict, reason: str) -> dict:
    ax1, ay1, ax2, ay2, _, _ = _geometry(a)
    bx1, by1, bx2, by2, _, _ = _geometry(b)
    if reason == "same-line":
        ordered = sorted((a, b), key=lambda item: item["bbox"][0])
        separator = " "
    else:
        ordered = sorted((a, b), key=lambda item: (item["bbox"][1], item["bbox"][0]))
        separator = "\n"

    sources = []
    reasons = []
    for item in ordered:
        meta = item.get("mergeMeta", {})
        sources.extend(meta.get("sourceDialogueIndices", [item["_sourceIndex"]]))
        reasons.extend(meta.get("reasons", []))
    reasons.append(reason)
    return {
        "text": separator.join(item["text"] for item in ordered),
        "confidence": round(sum(float(item.get("confidence", 0)) for item in ordered) / 2, 4),
        "bbox": [min(ax1, bx1), min(ay1, by1), max(ax2, bx2), max(ay2, by2)],
        "_sourceIndex": min(sources),
        "mergeMeta": {
            "sourceDialogueIndices": sorted(set(sources)),
            "reasons": reasons,
        },
    }


def _has_nearby_row_barrier(a: dict, b: dict, items: list[dict]) -> bool:
    for anchor in (a, b):
        ax1, ay1, ax2, ay2, _, ah = _geometry(anchor)
        for other in items:
            if other is a or other is b:
                continue
            ox1, oy1, ox2, oy2, _, oh = _geometry(other)
            y_overlap = max(0, min(ay2, oy2) - max(ay1, oy1)) / min(ah, oh)
            horizontal_gap = max(0, max(ax1, ox1) - min(ax2, ox2))
            if y_overlap >= 0.3 and horizontal_gap <= 0.75 * ah:
                return True
    return False


def merge_page_dialogues(page: dict) -> list[dict]:
    items = []
    for index, dialogue in enumerate(page.get("dialogues", [])):
        item = copy.deepcopy(dialogue)
        item["_sourceIndex"] = index
        items.append(item)

    while True:
        best = None
        for i in range(len(items)):
            for j in range(i + 1, len(items)):
                candidate = _pair_score(items[i], items[j])
                if candidate is None:
                    continue
                score, reason = candidate
                if reason == "stacked-lines" and _has_nearby_row_barrier(items[i], items[j], items):
                    continue
                if best is None or score > best[0]:
                    best = (score, i, j, reason)
        if best is None:
            break
        _, i, j, reason = best
        merged = _merge_pair(items[i], items[j], reason)
        items = [item for k, item in enumerate(items) if k not in (i, j)] + [merged]

    items.sort(key=lambda item: (item["bbox"][1], item["bbox"][0]))
    for item in items:
        item.pop("_sourceIndex", None)
    return items


def adjust_work(data: dict) -> dict:
    adjusted = copy.deepcopy(data)
    adjusted["dialogueMergeVersion"] = 2
    for page in adjusted.get("pages", []):
        page["dialogues"] = merge_page_dialogues(page)
    return adjusted


def process_works(input_dir: str, output_dir: str, count: int) -> list[Path]:
    source_dir = Path(input_dir)
    destination = Path(output_dir)
    destination.mkdir(parents=True, exist_ok=True)
    written = []
    for path in sorted(source_dir.glob("*.json"))[:count]:
        with path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
        output_path = destination / path.name
        with output_path.open("w", encoding="utf-8") as handle:
            json.dump(adjust_work(data), handle, ensure_ascii=False, indent=2)
            handle.write("\n")
        written.append(output_path)
    return written


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Conservatively merge existing OCR dialogue boxes.")
    parser.add_argument("--input-dir", default="raw")
    parser.add_argument("--output-dir", default="raw-merged-v2")
    parser.add_argument("--count", type=int, default=10)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    written = process_works(args.input_dir, args.output_dir, args.count)
    print(f"wrote {len(written)} works to {os.path.abspath(args.output_dir)}")


if __name__ == "__main__":
    main()
