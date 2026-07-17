from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import modal
from tqdm import tqdm



ROOT = Path(__file__).resolve().parent
RAW_DIR = ROOT.parent / "violet-ocr" / "raw-merged-v2"
MODEL_DIR_NAME = "Qwen--Qwen3-Embedding-4B"
INPUT_VOLUME_NAME = "violet-llm-embedding-inputs"
RESULT_VOLUME_NAME = "violet-llm-embedding-results"

image = (
    modal.Image.debian_slim(python_version="3.12")
    .apt_install("tar", "zstd")
    .uv_pip_install("torch", "sentence-transformers", "numpy", "tqdm")
    .add_local_file(ROOT / "embed.py", "/app/embed.py", copy=True)
    .add_local_file(ROOT / "common.py", "/app/common.py", copy=True)
)

app = modal.App("violet-llm-embed-batch", image=image)
model_cache = modal.Volume.from_name("violet-llm-model-cache", create_if_missing=True)
input_volume = modal.Volume.from_name(INPUT_VOLUME_NAME, create_if_missing=True)
result_volume = modal.Volume.from_name(RESULT_VOLUME_NAME, create_if_missing=True)


def output_dir(output_name: str) -> Path:
    return ROOT / "outputs" / MODEL_DIR_NAME / output_name


def completed_work_ids(target: Path) -> set[int]:
    works_dir = target / "works"
    if not works_dir.exists():
        return set()
    completed: set[int] = set()
    for path in works_dir.iterdir():
        if path.is_dir() and path.name.isdigit() and (path / "metadata.json").exists():
            completed.add(int(path.name))
    return completed


def select_missing_works(raw_dir: Path, completed: set[int], count: int) -> list[Work]:
    from common import Work

    if count < 1:
        raise ValueError("--work-count must be positive.")
    works = [
        Work(int(path.stem), path.resolve())
        for path in raw_dir.glob("*.json")
        if path.stem.isdigit() and int(path.stem) not in completed
    ]
    works.sort(key=lambda work: work.work_id, reverse=True)
    if len(works) < count:
        raise RuntimeError(
            f"Only {len(works)} unfinished numeric JSON files remain; requested {count}."
        )
    return works[:count]


def prepare_staging_dataset(
    works: list[Work],
    dataset_dir: Path,
    window_pages: int,
    stride_pages: int,
) -> dict[str, Any]:
    from common import make_chunks, write_json, write_jsonl

    (dataset_dir / "works").mkdir(parents=True)
    summaries: list[dict[str, Any]] = []
    for work in tqdm(works, desc="Preparing upload", unit="work"):
        chunks = make_chunks(work, window_pages, stride_pages)
        write_jsonl(dataset_dir / "works" / f"{work.work_id}.jsonl", chunks)
        summaries.append(
            {
                "work_id": work.work_id,
                "source_file": str(work.path),
                "chunk_count": len(chunks),
                "bubble_count": sum(chunk["bubble_count"] for chunk in chunks),
            }
        )
    manifest = {
        "schema_version": 1,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "selection": "numeric filename descending, completed local works excluded",
        "work_ids": [work.work_id for work in works],
        "window_pages": window_pages,
        "stride_pages": stride_pages,
        "works": summaries,
    }
    write_json(dataset_dir / "manifest.json", manifest)
    return manifest


def create_native_archive(source: Path, archive: Path) -> float:
    started = time.perf_counter()
    if os.name == "nt":
        command = [
            "tar",
            "-a",
            "-cf",
            str(archive),
            "-C",
            str(source.parent),
            source.name,
        ]
    else:
        command = [
            "tar",
            "-I",
            "zstd -T0 -1",
            "-cf",
            str(archive),
            "-C",
            str(source.parent),
            source.name,
        ]
    subprocess.run(command, check=True)
    return time.perf_counter() - started


def extract_native_archive(archive: Path, destination: Path) -> float:
    started = time.perf_counter()
    destination.mkdir(parents=True, exist_ok=True)
    if os.name == "nt":
        command = ["tar", "-xf", str(archive), "-C", str(destination)]
    else:
        command = [
            "tar",
            "-I",
            "zstd -d -T0",
            "-xf",
            str(archive),
            "-C",
            str(destination),
        ]
    subprocess.run(command, check=True)
    return time.perf_counter() - started


def run_logged_subprocess(
    command: list[str],
    *,
    cwd: str,
    env: dict[str, str],
    log_path: Path,
) -> None:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("wb") as log_handle:
        process = subprocess.Popen(
            command,
            cwd=cwd,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        assert process.stdout is not None
        while chunk := process.stdout.read1(64 * 1024):
            log_handle.write(chunk)
            log_handle.flush()
            console = getattr(sys.stdout, "buffer", None)
            if console is not None:
                console.write(chunk)
                console.flush()
            else:
                print(chunk.decode("utf-8", errors="replace"), end="", flush=True)
        return_code = process.wait()
    if return_code:
        raise subprocess.CalledProcessError(return_code, command)


def create_input_archive(dataset_dir: Path, archive: Path) -> None:
    files = [path for path in dataset_dir.rglob("*") if path.is_file()]
    source_bytes = sum(path.stat().st_size for path in files)
    print(f"Creating native tar.zst from {len(files):,} files ...", flush=True)
    elapsed = create_native_archive(dataset_dir, archive)
    archive_bytes = archive.stat().st_size
    ratio = archive_bytes / max(source_bytes, 1)
    print(
        f"Created {archive.name} in {elapsed:.2f}s: "
        f"{source_bytes / 1_000_000_000:.2f} GB -> "
        f"{archive_bytes / 1_000_000_000:.2f} GB ({ratio:.1%})",
        flush=True,
    )


def upload_dataset(run_id: str, dataset_dir: Path) -> None:
    archive = dataset_dir.parent / f"{run_id}.tar.zst"
    create_input_archive(dataset_dir, archive)
    print(
        f"Uploading one archive to Modal Volume "
        f"{INPUT_VOLUME_NAME}/{archive.name} ...",
        flush=True,
    )
    with input_volume.batch_upload() as batch:
        batch.put_file(str(archive), f"/{archive.name}")
    print("Input archive upload committed.", flush=True)


@app.function(
    gpu="H100",
    timeout=6 * 60 * 60,
    volumes={
        "/cache": model_cache,
        "/inputs": input_volume,
        "/results": result_volume,
    },
)
def embed_pending(
    run_id: str,
    max_batch_tokens: int,
    batch_size: int,
    work_buffer_size: int,
) -> dict[str, object]:
    import torch

    remote_archive = Path("/inputs") / f"{run_id}.tar.zst"
    if not remote_archive.exists():
        raise FileNotFoundError(f"Uploaded dataset archive is missing: {remote_archive}")

    app_data = Path("/app/data")
    app_data.mkdir(exist_ok=True)
    input_extract_seconds = extract_native_archive(remote_archive, app_data)
    remote_dataset = app_data / "modal-pending"
    if not (remote_dataset / "manifest.json").exists():
        raise FileNotFoundError(f"Extracted dataset is missing: {remote_dataset}")

    env = os.environ.copy()
    env["HF_HOME"] = "/cache/huggingface"
    generated = Path("/app/outputs") / MODEL_DIR_NAME / run_id
    generated.mkdir(parents=True, exist_ok=True)
    remote_log = generated / "remote.log"
    started_at = time.perf_counter()
    run_logged_subprocess(
        [
            sys.executable,
            "/app/embed.py",
            "--dataset-name",
            "modal-pending",
            "--output-name",
            run_id,
            "--max-batch-tokens",
            str(max_batch_tokens),
            "--batch-size",
            str(batch_size),
            "--work-buffer-size",
            str(work_buffer_size),
        ],
        cwd="/app",
        env=env,
        log_path=remote_log,
    )
    elapsed = time.perf_counter() - started_at

    archive = Path("/results") / f"{run_id}.tar.zst"
    if archive.exists():
        archive.unlink()
    print(f"Creating native result archive {archive.name} ...", flush=True)
    result_archive_seconds = create_native_archive(generated, archive)
    print(
        f"Created result archive in {result_archive_seconds:.2f}s "
        f"({archive.stat().st_size / 1_000_000_000:.2f} GB).",
        flush=True,
    )

    metadata_paths = list((generated / "works").glob("*/metadata.json"))
    metadata = [json.loads(path.read_text(encoding="utf-8")) for path in metadata_paths]
    total_tokens = sum(int(item.get("input_token_count", 0)) for item in metadata)
    total_chunks = sum(int(item.get("chunk_count", 0)) for item in metadata)
    model_cache.commit()
    result_volume.commit()
    return {
        "gpu": torch.cuda.get_device_name(0),
        "works": len(metadata_paths),
        "chunks": total_chunks,
        "input_tokens": total_tokens,
        "elapsed_seconds_including_model_load": elapsed,
        "tokens_per_second_including_model_load": total_tokens / max(elapsed, 0.001),
        "archive": archive.name,
        "input_extract_seconds": input_extract_seconds,
        "result_archive_seconds": result_archive_seconds,
        "archive_bytes": archive.stat().st_size,
    }


def download_and_merge(
    run_id: str,
    archive_name: str,
    expected_ids: set[int],
    target: Path,
) -> tuple[int, int]:
    target_works = target / "works"
    target_works.mkdir(parents=True, exist_ok=True)
    runtime_dir = ROOT / ".runtime"
    runtime_dir.mkdir(exist_ok=True)

    with tempfile.TemporaryDirectory(dir=runtime_dir, prefix="modal-download-") as temporary:
        temporary_dir = Path(temporary)
        archive = temporary_dir / archive_name
        print(f"Downloading Modal result {archive_name} ...")
        with archive.open("wb") as handle:
            for chunk in result_volume.read_file(archive_name):
                handle.write(chunk)
        print(f"Extracting native tar.zst {archive_name} ...")
        extract_seconds = extract_native_archive(archive, temporary_dir)
        print(f"Extracted result in {extract_seconds:.2f}s.")

        extracted = temporary_dir / run_id
        extracted_works = extracted / "works"
        remote_log = extracted / "remote.log"
        if remote_log.exists():
            shutil.copy2(remote_log, runtime_dir / f"modal-{run_id}.remote.log")
        actual_ids = {
            int(path.name)
            for path in extracted_works.iterdir()
            if path.is_dir()
            and path.name.isdigit()
            and (path / "metadata.json").exists()
            and (path / "embeddings.npy").exists()
            and (path / "chunks.jsonl").exists()
        }
        missing = expected_ids - actual_ids
        unexpected = actual_ids - expected_ids
        if missing or unexpected:
            raise RuntimeError(
                f"Result ID mismatch: missing={sorted(missing)[:10]}, "
                f"unexpected={sorted(unexpected)[:10]}"
            )

        if not (target / "manifest.json").exists():
            shutil.copy2(extracted / "manifest.json", target / "manifest.json")

        merged = 0
        skipped = 0
        for work_id in sorted(expected_ids, reverse=True):
            source = extracted_works / str(work_id)
            destination = target_works / str(work_id)
            if (destination / "metadata.json").exists():
                skipped += 1
                continue
            if destination.exists():
                raise FileExistsError(
                    f"Incomplete local work directory blocks merge: {destination}"
                )
            os.replace(source, destination)
            merged += 1
    return merged, skipped


def cleanup_remote(run_id: str, archive_name: str) -> None:
    input_volume.remove_file(f"{run_id}.tar.zst")
    result_volume.remove_file(archive_name)


@app.local_entrypoint()
def main(
    work_count: int = 5000,
    output_name: str = "latest-5000",
    gpu: str = "H100",
    max_batch_tokens: int = 16384,
    batch_size: int = 256,
    work_buffer_size: int = 64,
    window_pages: int = 3,
    stride_pages: int = 2,
    keep_remote: bool = False,
) -> None:
    target = output_dir(output_name)
    completed = completed_work_ids(target)
    selected = select_missing_works(RAW_DIR.resolve(), completed, work_count)
    expected_ids = {work.work_id for work in selected}
    run_id = (
        datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
        + "-"
        + uuid.uuid4().hex[:8]
    )
    print(
        f"Local output has {len(completed):,} completed works. "
        f"Selected the next {len(selected):,}: "
        f"{selected[0].work_id} .. {selected[-1].work_id}"
    )

    runtime_dir = ROOT / ".runtime"
    runtime_dir.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=runtime_dir, prefix="modal-upload-") as temporary:
        dataset_dir = Path(temporary) / "modal-pending"
        prepare_staging_dataset(selected, dataset_dir, window_pages, stride_pages)
        upload_dataset(run_id, dataset_dir)

    print(f"Running {len(selected):,} works on Modal {gpu} ...")
    stats = embed_pending.with_options(gpu=gpu).remote(
        run_id,
        max_batch_tokens,
        batch_size,
        work_buffer_size,
    )
    merged, skipped = download_and_merge(
        run_id,
        str(stats["archive"]),
        expected_ids,
        target,
    )
    if not keep_remote:
        cleanup_remote(run_id, str(stats["archive"]))

    final_count = len(completed_work_ids(target))
    print(
        f"GPU={stats['gpu']} remote_works={stats['works']} chunks={stats['chunks']} "
        f"input_tokens={int(stats['input_tokens']):,} "
        f"elapsed={float(stats['elapsed_seconds_including_model_load']):.2f}s "
        f"tok/s={float(stats['tokens_per_second_including_model_load']):,.0f}"
    )
    print(
        f"Remote input extract={float(stats['input_extract_seconds']):.2f}s, "
        f"result archive={float(stats['result_archive_seconds']):.2f}s, "
        f"result size={int(stats['archive_bytes']) / 1_000_000:.2f} MB"
    )
    print(
        f"Merged {merged:,} works, skipped {skipped:,} concurrently completed works. "
        f"Local total: {final_count:,}"
    )
    print(
        f'python search.py "query" --output-name {output_name} '
        "--candidate-k 300 --top-k 100"
    )
