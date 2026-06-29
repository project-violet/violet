from __future__ import annotations

import json
import os
import sys


SUPPORTED_EXTS = {".webp", ".avif", ".png", ".jpg", ".jpeg", ".bmp", ".tiff"}


def configure_text_output() -> None:
    for stream_name in ("stdout", "stderr"):
        stream = getattr(sys, stream_name, None)
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")


def _find(parent: list[int], i: int) -> int:
    while parent[i] != i:
        parent[i] = parent[parent[i]]
        i = parent[i]
    return i


def _union(parent: list[int], rank: list[int], a: int, b: int) -> None:
    ra, rb = _find(parent, a), _find(parent, b)
    if ra == rb:
        return
    if rank[ra] < rank[rb]:
        ra, rb = rb, ra
    parent[rb] = ra
    if rank[ra] == rank[rb]:
        rank[ra] += 1


def group_into_dialogues(texts: list[dict], img_width: int, img_height: int) -> list[dict]:
    n = len(texts)
    if n == 0:
        return []

    thresh_x = img_width * 0.025
    thresh_y = img_height * 0.05
    centers = []
    for item in texts:
        bbox = item["bbox"]
        centers.append(((bbox[0] + bbox[2]) / 2, (bbox[1] + bbox[3]) / 2))

    parent = list(range(n))
    rank = [0] * n
    for i in range(n):
        for j in range(i + 1, n):
            dx = abs(centers[i][0] - centers[j][0])
            dy = abs(centers[i][1] - centers[j][1])
            if dx < thresh_x and dy < thresh_y:
                _union(parent, rank, i, j)

    groups: dict[int, list[int]] = {}
    for i in range(n):
        groups.setdefault(_find(parent, i), []).append(i)

    dialogues = []
    for indices in groups.values():
        indices.sort(key=lambda index: centers[index][1])
        lines = [texts[index] for index in indices]
        merged_text = " ".join(item["text"] for item in lines)
        avg_conf = sum(item["confidence"] for item in lines) / len(lines)
        dialogues.append(
            {
                "text": merged_text,
                "confidence": round(avg_conf, 4),
                "bbox": [
                    min(item["bbox"][0] for item in lines),
                    min(item["bbox"][1] for item in lines),
                    max(item["bbox"][2] for item in lines),
                    max(item["bbox"][3] for item in lines),
                ],
            }
        )

    dialogues.sort(key=lambda item: item["bbox"][1])
    return dialogues


def get_sorted_images(article_dir: str) -> list[tuple[int, str]]:
    images = []
    for name in os.listdir(article_dir):
        stem, ext = os.path.splitext(name)
        if ext.lower() in SUPPORTED_EXTS and stem.isdigit():
            images.append((int(stem), os.path.join(article_dir, name)))
    images.sort(key=lambda item: item[0])
    return images


def save_ocr_result(result: dict, output_dir: str) -> str:
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, f"{result['articleId']}.json")
    with open(output_path, "w", encoding="utf-8") as output:
        json.dump(result, output, ensure_ascii=False, indent=2)
    return output_path
