import argparse
import copy
import http.client
import json
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path
from typing import Callable
from urllib import error, request


DEFAULT_BASE_URL = "http://localhost:8001/v1"
DEFAULT_MODEL = "exaone3.5:7.8b-awq"


OUTPUT_SCHEMA = {
    "type": "object",
    "properties": {
        "f": {
            "type": "array",
            "items": {"type": "string"},
        }
    },
    "required": ["f"],
}


SYSTEM_PROMPT = """한국어 OCR 교정기. JSON만 출력.
입력 t 배열과 같은 길이의 f 배열로 교정문만 반환.
오탈자만 고치고 확실하지 않으면 원문 유지.
크레딧/숫자/페이지표식은 억지로 대사화 금지.
"""


@dataclass
class ProcessResult:
    input_path: Path
    output_path: Path
    total_items: int
    changed: int
    written: bool
    skipped: bool = False


class VllmClient:
    def __init__(
        self,
        base_url: str = DEFAULT_BASE_URL,
        model: str = DEFAULT_MODEL,
        timeout: float = 300.0,
        retries: int = 2,
        retry_sleep: float = 1.0,
        print_llm_output: bool = False,
    ):
        self.base_url = base_url.rstrip("/")
        self.model = model
        self.timeout = timeout
        self.retries = retries
        self.retry_sleep = retry_sleep
        self.print_llm_output = print_llm_output

    def build_payload(self, items: list[dict]) -> dict:
        user_prompt = (
            "OCR 교정. f는 t와 같은 길이, 같은 순서.\n"
            + json.dumps({"t": [item["text"] for item in items]}, ensure_ascii=False)
        )
        return {
            "model": self.model,
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user_prompt},
            ],
            "stream": False,
            "temperature": 0,
            "response_format": {
                "type": "json_schema",
                "json_schema": {
                    "name": "ocr_fix_result",
                    "schema": OUTPUT_SCHEMA,
                    "strict": True,
                },
            },
        }

    def fix_items(self, items: list[dict]) -> list[dict]:
        payload = json.dumps(self.build_payload(items), ensure_ascii=False).encode("utf-8")
        req = request.Request(
            f"{self.base_url}/chat/completions",
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        for attempt in range(self.retries + 1):
            try:
                with request.urlopen(req, timeout=self.timeout) as response:
                    api_data = json.loads(response.read().decode("utf-8"))
                break
            except (TimeoutError, http.client.RemoteDisconnected, http.client.IncompleteRead):
                if attempt >= self.retries:
                    raise
                time.sleep(self.retry_sleep * (attempt + 1))
        content = api_data["choices"][0]["message"]["content"]
        parsed = json.loads(content)
        fixed_items = parsed["f"]
        if not isinstance(fixed_items, list):
            raise ValueError("vLLM response f is not a list")
        if len(fixed_items) != len(items):
            raise ValueError(
                f"vLLM response length mismatch: expected {len(items)}, got {len(fixed_items)}"
            )
        if not all(isinstance(value, str) for value in fixed_items):
            raise ValueError("vLLM response f contains non-string values")
        if self.print_llm_output:
            print("[llm-output]", flush=True)
            for item, fixed in zip(items, fixed_items):
                print(
                    f"{json.dumps(item['text'], ensure_ascii=False)} -> "
                    f"{json.dumps(fixed, ensure_ascii=False)}",
                    flush=True,
                )
        return fixed_items

def parse_page_range(value: str | None) -> set[int] | None:
    if not value:
        return None
    pages: set[int] = set()
    for part in value.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            start_text, end_text = part.split("-", 1)
            start = int(start_text)
            end = int(end_text)
            pages.update(range(start, end + 1))
        else:
            pages.add(int(part))
    return pages


def iter_items(
    data: dict,
    low_confidence_only: float | None = None,
    page_range: set[int] | None = None,
) -> list[dict]:
    items: list[dict] = []
    for page_obj in data.get("pages", []):
        page = page_obj.get("page")
        if page_range is not None and page not in page_range:
            continue
        for index, dialogue in enumerate(page_obj.get("dialogues", [])):
            text = dialogue.get("text", "")
            if not text:
                continue
            confidence = dialogue.get("confidence")
            if low_confidence_only is not None:
                if confidence is None or confidence >= low_confidence_only:
                    continue
            items.append(
                {
                    "page": int(page),
                    "index": index,
                    "text": text,
                    "confidence": confidence,
                }
            )
    return items


def build_chunks(items: list[dict], chunk_pages: int, chunk_items: int) -> list[list[dict]]:
    chunks: list[list[dict]] = []
    current: list[dict] = []
    current_start: int | None = None
    for item in items:
        page = item["page"]
        if current_start is None:
            current_start = page
        if current and (page - current_start >= chunk_pages or len(current) >= chunk_items):
            chunks.append(current)
            current = []
            current_start = page
        current.append(item)
    if current:
        chunks.append(current)
    return chunks


def describe_pages(chunk: list[dict]) -> str:
    pages = sorted({item["page"] for item in chunk})
    if not pages:
        return "-"
    ranges: list[str] = []
    start = pages[0]
    previous = pages[0]
    for page in pages[1:]:
        if page == previous + 1:
            previous = page
            continue
        ranges.append(f"{start}" if start == previous else f"{start}-{previous}")
        start = page
        previous = page
    ranges.append(f"{start}" if start == previous else f"{start}-{previous}")
    return ",".join(ranges)


def fix_chunk_with_fallback(
    client: VllmClient,
    chunk: list[dict],
    progress: Callable[[dict], None] | None = None,
    input_path: Path | None = None,
) -> list[str]:
    try:
        return client.fix_items(chunk)
    except (
        KeyError,
        ValueError,
        json.JSONDecodeError,
        TimeoutError,
        http.client.RemoteDisconnected,
        http.client.IncompleteRead,
    ) as exc:
        if len(chunk) <= 1:
            if progress is not None:
                progress(
                    {
                        "event": "chunk_fallback_original",
                        "input_path": input_path,
                        "pages": describe_pages(chunk),
                        "items": len(chunk),
                        "error": str(exc),
                    }
                )
            return [item["text"] for item in chunk]

        midpoint = len(chunk) // 2
        left = chunk[:midpoint]
        right = chunk[midpoint:]
        if progress is not None:
            progress(
                {
                    "event": "chunk_split",
                    "input_path": input_path,
                    "pages": describe_pages(chunk),
                    "items": len(chunk),
                    "left_items": len(left),
                    "right_items": len(right),
                    "error": str(exc),
                }
            )
        return fix_chunk_with_fallback(client, left, progress, input_path) + fix_chunk_with_fallback(
            client, right, progress, input_path
        )


def apply_fixed_texts(data: dict, items: list[dict], fixed_texts: list[str]) -> int:
    pages_by_number = {page_obj.get("page"): page_obj for page_obj in data.get("pages", [])}
    changed = 0
    if len(items) != len(fixed_texts):
        raise ValueError(f"fixed text length mismatch: expected {len(items)}, got {len(fixed_texts)}")
    for item, fixed in zip(items, fixed_texts):
        page_obj = pages_by_number.get(item.get("page"))
        if page_obj is None:
            continue
        dialogues = page_obj.get("dialogues", [])
        index = item.get("index")
        if not isinstance(index, int) or index < 0 or index >= len(dialogues):
            continue
        if not isinstance(fixed, str):
            continue
        if dialogues[index].get("text") != fixed:
            dialogues[index]["text"] = fixed
            changed += 1
    return changed


def process_file(
    input_path: Path,
    output_dir: Path,
    client: VllmClient,
    chunk_pages: int,
    chunk_items: int,
    workers: int,
    overwrite: bool,
    low_confidence_only: float | None,
    page_range: set[int] | None,
    dry_run: bool,
    progress: Callable[[dict], None] | None = None,
) -> ProcessResult:
    output_path = output_dir / input_path.name
    if output_path.exists() and not overwrite and not dry_run:
        return ProcessResult(input_path, output_path, 0, 0, False, skipped=True)

    with input_path.open(encoding="utf-8") as f:
        source = json.load(f)
    fixed = copy.deepcopy(source)
    items = iter_items(
        fixed,
        low_confidence_only=low_confidence_only,
        page_range=page_range,
    )
    chunks = build_chunks(items, chunk_pages=chunk_pages, chunk_items=chunk_items)

    if progress is not None:
        progress(
            {
                "event": "file_start",
                "input_path": input_path,
                "output_path": output_path,
                "total_items": len(items),
                "chunk_total": len(chunks),
            }
        )

    fixed_chunks: list[list[str] | None] = [None] * len(chunks)

    def fix_one(chunk_number: int, chunk: list[dict]) -> tuple[int, list[str]]:
        if progress is not None:
            progress(
                {
                    "event": "chunk_start",
                    "input_path": input_path,
                    "chunk_number": chunk_number,
                    "chunk_total": len(chunks),
                    "items": len(chunk),
                    "pages": describe_pages(chunk),
                }
            )
        fixed_texts = fix_chunk_with_fallback(client, chunk, progress, input_path)
        return chunk_number, fixed_texts

    if workers <= 1 or len(chunks) <= 1:
        for chunk_number, chunk in enumerate(chunks, start=1):
            _, fixed_texts = fix_one(chunk_number, chunk)
            fixed_chunks[chunk_number - 1] = fixed_texts
    else:
        with ThreadPoolExecutor(max_workers=workers) as executor:
            futures = {
                executor.submit(fix_one, chunk_number, chunk): chunk_number
                for chunk_number, chunk in enumerate(chunks, start=1)
            }
            for future in as_completed(futures):
                chunk_number, fixed_texts = future.result()
                fixed_chunks[chunk_number - 1] = fixed_texts

    changed = 0
    for chunk_number, chunk in enumerate(chunks, start=1):
        fixed_texts = fixed_chunks[chunk_number - 1]
        if fixed_texts is None:
            raise RuntimeError(f"missing fixed texts for chunk {chunk_number}")
        chunk_changed = apply_fixed_texts(fixed, chunk, fixed_texts)
        changed += chunk_changed
        if progress is not None:
            progress(
                {
                    "event": "chunk_done",
                    "input_path": input_path,
                    "chunk_number": chunk_number,
                    "chunk_total": len(chunks),
                    "items": len(chunk),
                    "pages": describe_pages(chunk),
                    "changed": chunk_changed,
                    "changed_total": changed,
                }
            )

    if not dry_run:
        output_dir.mkdir(parents=True, exist_ok=True)
        with output_path.open("w", encoding="utf-8") as f:
            json.dump(fixed, f, ensure_ascii=False, indent=2)
            f.write("\n")

    if progress is not None:
        progress(
            {
                "event": "file_done",
                "input_path": input_path,
                "output_path": output_path,
                "total_items": len(items),
                "chunk_total": len(chunks),
                "changed": changed,
                "written": not dry_run,
            }
        )

    return ProcessResult(input_path, output_path, len(items), changed, not dry_run)


def input_files(input_dir: Path, single_file: Path | None, limit: int | None) -> list[Path]:
    if single_file is not None:
        return [single_file]
    files = sorted(path for path in input_dir.glob("*.json") if path.is_file())
    if limit is not None:
        return files[:limit]
    return files


def print_progress(event: dict, file_number: int, file_total: int) -> None:
    prefix = f"[file {file_number}/{file_total}] {event['input_path']}"
    if event["event"] == "file_start":
        print(
            f"{prefix} start items={event['total_items']} chunks={event['chunk_total']}",
            flush=True,
        )
    elif event["event"] == "chunk_start":
        print(
            f"{prefix} chunk {event['chunk_number']}/{event['chunk_total']} "
            f"pages={event['pages']} items={event['items']} sending...",
            flush=True,
        )
    elif event["event"] == "chunk_done":
        print(
            f"{prefix} chunk {event['chunk_number']}/{event['chunk_total']} "
            f"done changed={event['changed']} total_changed={event['changed_total']}",
            flush=True,
        )
    elif event["event"] == "chunk_split":
        print(
            f"{prefix} split pages={event['pages']} items={event['items']} -> "
            f"{event['left_items']}+{event['right_items']} because {event['error']}",
            flush=True,
        )
    elif event["event"] == "chunk_fallback_original":
        print(
            f"{prefix} keep-original pages={event['pages']} items={event['items']} "
            f"because {event['error']}",
            flush=True,
        )
    elif event["event"] == "file_done":
        print(
            f"{prefix} done -> {event['output_path']} "
            f"items={event['total_items']} changed={event['changed']}",
            flush=True,
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fix violet-ocr raw OCR text with a local vLLM OpenAI-compatible API."
    )
    parser.add_argument("--input", type=Path, default=Path("raw"), help="Input raw JSON directory.")
    parser.add_argument("--file", type=Path, help="Process one JSON file instead of the input directory.")
    parser.add_argument("--output", type=Path, default=Path("raw-fixed"), help="Output directory.")
    parser.add_argument("--model", default=DEFAULT_MODEL, help=f"vLLM served model. Default: {DEFAULT_MODEL}")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL, help=f"vLLM OpenAI base URL. Default: {DEFAULT_BASE_URL}")
    parser.add_argument("--timeout", type=float, default=300.0, help="Request timeout seconds.")
    parser.add_argument("--retries", type=int, default=2, help="Retries per vLLM request on transient network timeouts.")
    parser.add_argument("--retry-sleep", type=float, default=1.0, help="Base retry sleep seconds for transient failures.")
    parser.add_argument("--chunk-pages", type=int, default=10, help="Pages per vLLM request.")
    parser.add_argument("--chunk-items", type=int, default=16, help="Max OCR text items per vLLM request.")
    parser.add_argument("--workers", type=int, default=1, help="Parallel vLLM requests. Default: 1.")
    parser.add_argument("--overwrite", action="store_true", help="Overwrite existing raw-fixed files.")
    parser.add_argument("--limit", type=int, help="Limit number of input files when using --input.")
    parser.add_argument("--pages", help="Only process pages like 1,2,5-10.")
    parser.add_argument(
        "--low-confidence-only",
        type=float,
        help="Only fix dialogues whose confidence is below this value, e.g. 0.85.",
    )
    parser.add_argument("--dry-run", action="store_true", help="Call vLLM but do not write output files.")
    parser.add_argument(
        "--print-llm-output",
        action="store_true",
        help="Print input/output text pairs for every chunk.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    client = VllmClient(
        base_url=args.base_url,
        model=args.model,
        timeout=args.timeout,
        retries=args.retries,
        retry_sleep=args.retry_sleep,
        print_llm_output=args.print_llm_output,
    )
    page_range = parse_page_range(args.pages)
    files = input_files(args.input, args.file, args.limit)
    if not files:
        print("No input JSON files found.", file=sys.stderr)
        return 1

    for file_number, path in enumerate(files, start=1):
        try:
            result = process_file(
                input_path=path,
                output_dir=args.output,
                client=client,
                chunk_pages=args.chunk_pages,
                chunk_items=args.chunk_items,
                workers=args.workers,
                overwrite=args.overwrite,
                low_confidence_only=args.low_confidence_only,
                page_range=page_range,
                dry_run=args.dry_run,
                progress=lambda event, n=file_number: print_progress(event, n, len(files)),
            )
        except error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            print(f"ERROR {path}: vLLM HTTP {exc.code}: {body}", file=sys.stderr)
            return 1
        except error.URLError as exc:
            print(f"ERROR {path}: vLLM is not reachable: {exc.reason}", file=sys.stderr)
            return 1
        except (KeyError, ValueError, json.JSONDecodeError) as exc:
            print(f"ERROR {path}: invalid response or JSON: {exc}", file=sys.stderr)
            return 1

        if result.skipped:
            print(f"[file {file_number}/{len(files)}] SKIP {path} -> {result.output_path}", flush=True)
        else:
            action = "DRY" if args.dry_run else "WROTE"
            print(
                f"[file {file_number}/{len(files)}] {action} {path} -> {result.output_path} "
                f"items={result.total_items} changed={result.changed}",
                flush=True,
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
