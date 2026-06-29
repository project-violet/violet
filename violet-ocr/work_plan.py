from __future__ import annotations

import argparse
import json
import os
import shutil
import sqlite3
import threading
import time
from dataclasses import dataclass

from ocr_common import SUPPORTED_EXTS


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TARGET_IDS_PATH = os.path.join(SCRIPT_DIR, "works", "target_ids.json")
FAILED_IDS_PATH = os.path.join(SCRIPT_DIR, "works", "failed_ids.jsonl")
DEFAULT_DB_PATH = os.path.abspath(
    os.path.join(SCRIPT_DIR, "..", "violet-web", "packages", "backend", "data", "data.db")
)
TMP_DIR = os.path.join(SCRIPT_DIR, "tmp")
RAW_DIR = os.path.join(SCRIPT_DIR, "raw")
GO_DOWNLOADER = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "fast-dl", "fast-dl.exe"))
EXPECTED_COUNTS_QUERY_CHUNK_SIZE = 30000


@dataclass
class DownloadResult:
    work_id: str
    ok: bool
    skipped: bool
    directory: str
    files: int
    expected_files: int | None
    elapsed: float
    returncode: int = 0
    error: str | None = None
    page_limit_skipped: bool = False


@dataclass
class OcrResult:
    work_id: str
    ok: bool
    skipped: bool
    pages: int
    dialogues: int
    elapsed: float
    preprocess_elapsed: float = 0.0
    output_path: str | None = None
    error: str | None = None
    page_limit_skipped: bool = False


@dataclass
class WorkPlan:
    raw_skips: list[str]
    page_limit_skips: list[str]
    failed_skips: list[str]
    existing_downloads: list[DownloadResult]
    download_ids: list[str]
    empty_tmp_removed: int

    @property
    def needs_ocr_count(self) -> int:
        return len(self.existing_downloads) + len(self.download_ids)


class Progress:
    def __init__(self, total: int, download_total: int):
        self.total = total
        self.download_total = download_total
        self.started_at = time.perf_counter()
        self.lock = threading.Lock()
        self.stop = threading.Event()
        self.download_active: dict[str, tuple[int, int | None]] = {}
        self.download_done = 0
        self.download_skipped = 0
        self.download_failed = 0
        self.ocr_active: dict[str, tuple[int, int]] = {}
        self.ocr_done = 0
        self.ocr_skipped = 0
        self.ocr_failed = 0

    def set_download_active(self, work_id: str, seen: int, expected: int | None) -> None:
        with self.lock:
            self.download_active[work_id] = (seen, expected)

    def finish_download(self, result: DownloadResult) -> None:
        with self.lock:
            self.download_active.pop(result.work_id, None)
            self.download_done += 1
            if result.skipped:
                self.download_skipped += 1
            if not result.ok:
                self.download_failed += 1

    def set_ocr_active(self, work_id: str, done: int, total: int) -> None:
        with self.lock:
            self.ocr_active[work_id] = (done, total)

    def finish_ocr(self, result: OcrResult) -> None:
        with self.lock:
            self.ocr_active.pop(result.work_id, None)
            if result.skipped:
                self.ocr_skipped += 1
            elif result.ok:
                self.ocr_done += 1
            else:
                self.ocr_failed += 1

    def snapshot(self) -> tuple[str, str, str]:
        with self.lock:
            active = ", ".join(
                f"{wid} {seen}/{expected if expected is not None else '?'}"
                for wid, (seen, expected) in sorted(self.download_active.items())
            ) or "-"
            ocr_active = ", ".join(
                f"{wid} {done}/{total}"
                for wid, (done, total) in sorted(self.ocr_active.items())
            ) or "-"
            completed = self.ocr_done + self.ocr_skipped + self.ocr_failed
            elapsed = time.perf_counter() - self.started_at
            return (
                f"[download] done {self.download_done}/{self.download_total} "
                f"skip {self.download_skipped} fail {self.download_failed} active {active}",
                f"[ocr] done {self.ocr_done} skip {self.ocr_skipped} "
                f"fail {self.ocr_failed} active {ocr_active}",
                f"[overall] works {completed}/{self.total} elapsed {elapsed:.0f}s",
            )


def load_target_ids(path: str, args: argparse.Namespace) -> list[str]:
    if args.count <= 0:
        raise ValueError("count must be greater than 0")

    if args.ids:
        ids = args.ids
    else:
        with open(path, encoding="utf-8") as input_file:
            ids = json.load(input_file)
        ids = ids[-args.count :]

    normalized = []
    for work_id in ids:
        work_id = str(work_id)
        if not work_id.isdigit():
            raise ValueError(f"Invalid work ID: {work_id}")
        normalized.append(work_id)
    return normalized


def load_expected_file_counts(db_path: str, ids: list[str]) -> dict[str, int]:
    if not os.path.exists(db_path) or not ids:
        return {}

    result: dict[str, int] = {}
    con = sqlite3.connect(db_path)
    try:
        for offset in range(0, len(ids), EXPECTED_COUNTS_QUERY_CHUNK_SIZE):
            chunk = ids[offset : offset + EXPECTED_COUNTS_QUERY_CHUNK_SIZE]
            placeholders = ",".join("?" for _ in chunk)
            query = f"select Id, Files from HitomiColumnModel where Id in ({placeholders})"
            result.update(
                {str(work_id): int(files) for work_id, files in con.execute(query, chunk)}
            )
        return result
    finally:
        con.close()


def load_failed_download_ids(path: str) -> set[str]:
    failed: set[str] = set()
    if not path or not os.path.exists(path):
        return failed
    with open(path, encoding="utf-8") as input_file:
        for raw_line in input_file:
            line = raw_line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            if record.get("stage") == "download" and record.get("id"):
                failed.add(str(record["id"]))
    return failed


def count_images(directory: str) -> int:
    if not os.path.isdir(directory):
        return 0
    count = 0
    for name in os.listdir(directory):
        _, ext = os.path.splitext(name)
        if ext.lower() in SUPPORTED_EXTS:
            count += 1
    return count


def has_complete_download(directory: str, expected_files: int | None) -> tuple[bool, int]:
    existing = count_images(directory)
    if expected_files is None:
        return existing > 0, existing
    return existing >= expected_files, existing


def bootstrap_work_plan(
    ids: list[str],
    args: argparse.Namespace,
    expected_counts: dict[str, int],
) -> WorkPlan:
    raw_skips: list[str] = []
    page_limit_skips: list[str] = []
    failed_skips: list[str] = []
    existing_downloads: list[DownloadResult] = []
    download_ids: list[str] = []
    empty_tmp_removed = 0
    failed_download_ids = set()
    if not getattr(args, "retry_failed", False):
        failed_download_ids = load_failed_download_ids(getattr(args, "failed_ids", FAILED_IDS_PATH))

    for work_id in ids:
        raw_path = os.path.join(args.raw_dir, f"{work_id}.json")
        target_dir = os.path.abspath(os.path.join(args.tmp_dir, work_id))
        expected_files = expected_counts.get(work_id)
        existing_files = count_images(target_dir)

        if not args.keep_empty_tmp and os.path.isdir(target_dir) and existing_files == 0:
            shutil.rmtree(target_dir, ignore_errors=True)
            empty_tmp_removed += 1

        if os.path.exists(raw_path) and not args.force_ocr:
            raw_skips.append(work_id)
            continue

        if args.max_pages > 0 and expected_files and expected_files > args.max_pages:
            page_limit_skips.append(work_id)
            continue

        if work_id in failed_download_ids:
            failed_skips.append(work_id)
            continue

        complete, existing_files = has_complete_download(target_dir, expected_files)
        if complete and not args.force_download:
            existing_downloads.append(
                DownloadResult(
                    work_id=work_id,
                    ok=True,
                    skipped=True,
                    directory=target_dir,
                    files=existing_files,
                    expected_files=expected_files,
                    elapsed=0.0,
                )
            )
            continue

        download_ids.append(work_id)

    return WorkPlan(
        raw_skips=raw_skips,
        page_limit_skips=page_limit_skips,
        failed_skips=failed_skips,
        existing_downloads=existing_downloads,
        download_ids=download_ids,
        empty_tmp_removed=empty_tmp_removed,
    )


def progress_printer(progress: Progress, interval: float) -> None:
    while not progress.stop.wait(interval):
        for line in progress.snapshot():
            print(line, flush=True)


def write_failure(work_id: str, stage: str, error: str | None) -> None:
    os.makedirs(os.path.dirname(FAILED_IDS_PATH), exist_ok=True)
    with open(FAILED_IDS_PATH, "a", encoding="utf-8", newline="\n") as output:
        json.dump(
            {
                "id": work_id,
                "stage": stage,
                "error": error,
                "time": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            },
            output,
            ensure_ascii=False,
        )
        output.write("\n")


def print_summary(
    download_results: list[DownloadResult],
    ocr_results: list[OcrResult],
    total: float,
) -> None:
    pages = sum(result.pages for result in ocr_results)
    dialogues = sum(result.dialogues for result in ocr_results)
    download_sum = sum(result.elapsed for result in download_results)
    ocr_sum = sum(result.elapsed for result in ocr_results)
    download_fail = sum(1 for result in download_results if not result.ok)
    ocr_fail = sum(1 for result in ocr_results if not result.ok and not result.skipped)

    print()
    print("=" * 72)
    print("Summary")
    print("=" * 72)
    print(f"Downloads: {len(download_results) - download_fail}/{len(download_results)}")
    print(f"OCR: {len(ocr_results) - ocr_fail}/{len(ocr_results)}")
    print(f"Pages: {pages}")
    print(f"Dialogues: {dialogues}")
    print(f"Wall time: {total:.2f}s")
    print(f"Download time sum: {download_sum:.2f}s")
    print(f"OCR pipeline time sum: {ocr_sum:.2f}s")
    if pages and ocr_sum:
        print(f"OCR pipeline throughput: {pages / ocr_sum:.2f} pages/s")
