from __future__ import annotations

import os
import subprocess
import time

import trace_writer
from work_plan import DownloadResult, Progress, count_images, has_complete_download


def build_fast_dl_command(
    go_downloader: str,
    work_id: str,
    output_root: str,
    gallery_dl: str,
    file_workers: int,
    file_retries: int,
    max_pages: int,
) -> list[str]:
    return [
        go_downloader,
        "-download-work",
        work_id,
        "-tmp-dir",
        output_root,
        "-gallery-dl",
        gallery_dl,
        "-file-workers",
        str(file_workers),
        "-file-retries",
        str(file_retries),
        "-max-pages",
        str(max_pages),
    ]


def download_work_go(
    work_id: str,
    go_downloader: str,
    gallery_dl: str,
    output_root: str,
    expected_files: int | None,
    force: bool,
    file_workers: int,
    file_retries: int,
    max_pages: int,
    progress: Progress,
    trace_tid: str = "download-go",
) -> DownloadResult:
    t0 = time.perf_counter()
    target_dir = os.path.abspath(os.path.join(output_root, work_id))
    complete, existing_files = has_complete_download(target_dir, expected_files)
    if complete and not force:
        result = DownloadResult(
            work_id=work_id,
            ok=True,
            skipped=True,
            directory=target_dir,
            files=existing_files,
            expected_files=expected_files,
            elapsed=time.perf_counter() - t0,
        )
        progress.finish_download(result)
        trace_writer.TRACE.complete(
            f"download_go-{work_id}",
            "download",
            t0,
            time.perf_counter(),
            trace_tid,
            {"work_id": work_id, "skipped": True, "backend": "go"},
        )
        return result

    cmd = build_fast_dl_command(
        go_downloader=go_downloader,
        work_id=work_id,
        output_root=output_root,
        gallery_dl=gallery_dl,
        file_workers=file_workers,
        file_retries=file_retries,
        max_pages=max_pages,
    )
    progress.set_download_active(work_id, existing_files, expected_files)
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        files = count_images(target_dir)
        stdout = result.stdout.strip()
        if result.returncode == 0 and stdout.startswith("PAGE_LIMIT"):
            download = DownloadResult(
                work_id=work_id,
                ok=True,
                skipped=True,
                directory=target_dir,
                files=files,
                expected_files=expected_files,
                elapsed=time.perf_counter() - t0,
                page_limit_skipped=True,
            )
        else:
            if expected_files is None:
                ok = result.returncode == 0 and files > 0
            else:
                ok = result.returncode == 0 and files >= expected_files
            download = DownloadResult(
                work_id=work_id,
                ok=ok,
                skipped=False,
                directory=target_dir,
                files=files,
                expected_files=expected_files,
                elapsed=time.perf_counter() - t0,
                returncode=result.returncode,
                error=(result.stderr.strip() or stdout or None) if not ok else None,
            )
    except BaseException as exc:
        download = DownloadResult(
            work_id=work_id,
            ok=False,
            skipped=False,
            directory=target_dir,
            files=0,
            expected_files=expected_files,
            elapsed=time.perf_counter() - t0,
            returncode=127 if isinstance(exc, FileNotFoundError) else 1,
            error=str(exc),
        )

    progress.finish_download(download)
    trace_writer.TRACE.complete(
        f"download_go-{work_id}",
        "download",
        t0,
        time.perf_counter(),
        trace_tid,
        {
            "work_id": work_id,
            "ok": download.ok,
            "skipped": download.skipped,
            "page_limit": download.page_limit_skipped,
            "backend": "go",
            "files": download.files,
            "expected_files": download.expected_files,
            "returncode": download.returncode,
        },
    )
    return download
