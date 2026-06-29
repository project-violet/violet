"""
Download Hitomi works and OCR them through a TurboOCR server.

This script keeps the run-works orchestration shape, but replaces the local
PaddleOCR worker pool with HTTP requests to TurboOCR.
"""

from __future__ import annotations

import argparse
import http.client
import json
import os
import queue
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, as_completed, wait
from dataclasses import dataclass
from multiprocessing import freeze_support
from pathlib import Path
from urllib.parse import urlencode, urlparse

from PIL import Image

import fast_dl_runner
import ocr_common
import trace_writer
import work_plan


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_TURBOOCR_URL = "http://localhost:8000"
DEFAULT_TURBOOCR_IMAGE = "ghcr.io/aiptimizer/turboocr:v2.3.0"
DEFAULT_TURBOOCR_CONTAINER = "violet-turboocr"
_IMAGECODECS_MODULE = None
_IMAGECODECS_IMPORT_ATTEMPTED = False
_IMAGECODECS_IMPORT_ERROR: BaseException | None = None
_IMAGECODECS_LOCK = threading.Lock()


@dataclass
class TurboOcrConfig:
    base_url: str
    input_mode: str
    avif_decoder: str
    imagecodecs_numthreads: int
    threshold: float
    timeout: float
    retries: int
    retry_delay: float
    layout: bool
    reading_order: bool
    as_blocks: bool


class FatalTurboOcrError(RuntimeError):
    pass


class TurboOcrClient:
    def __init__(self, config: TurboOcrConfig):
        self.config = config
        parsed = urlparse(config.base_url.rstrip("/"))
        if parsed.scheme not in {"http", "https"}:
            raise ValueError(f"unsupported TurboOCR URL scheme: {parsed.scheme}")
        self.scheme = parsed.scheme
        self.host = parsed.hostname or "localhost"
        self.port = parsed.port or (443 if parsed.scheme == "https" else 80)
        self.base_path = parsed.path.rstrip("/")
        self._conn: http.client.HTTPConnection | http.client.HTTPSConnection | None = None

    def close(self) -> None:
        if self._conn is not None:
            try:
                self._conn.close()
            finally:
                self._conn = None

    def _connection(self) -> http.client.HTTPConnection | http.client.HTTPSConnection:
        if self._conn is None:
            cls = http.client.HTTPSConnection if self.scheme == "https" else http.client.HTTPConnection
            self._conn = cls(self.host, self.port, timeout=self.config.timeout)
        return self._conn

    def _query_path(self, endpoint: str) -> str:
        params = {
            "layout": "1" if self.config.layout else "0",
            "reading_order": "1" if self.config.reading_order else "0",
            "as_blocks": "1" if self.config.as_blocks else "0",
        }
        return f"{self.base_path}{endpoint}?{urlencode(params)}"

    def _post_json(
        self,
        endpoint: str,
        body: bytes,
        headers: dict[str, str],
        trace: "TraceRecorder | None" = None,
    ) -> dict:
        path = self._query_path(endpoint)
        last_error: BaseException | None = None
        for attempt in range(self.config.retries + 1):
            http_start = time.perf_counter()
            try:
                conn = self._connection()
                conn.request("POST", path, body=body, headers=headers)
                response = conn.getresponse()
                payload = response.read()
                http_end = time.perf_counter()
                status = response.status
                retry_after = response.getheader("Retry-After")
                inference_ms = response.getheader("X-Inference-Time-Ms")
                if trace is not None:
                    trace.complete(
                        "turboocr_http_request",
                        http_start,
                        http_end,
                        {
                            "endpoint": endpoint,
                            "status": status,
                            "attempt": attempt + 1,
                            "request_bytes": len(body),
                            "response_bytes": len(payload),
                            "inference_ms": inference_ms,
                        },
                    )
                if status == 503 and attempt < self.config.retries:
                    self.close()
                    delay = _parse_retry_after(retry_after, self.config.retry_delay)
                    if trace is not None:
                        trace.complete(
                            "turboocr_retry_wait",
                            time.perf_counter(),
                            time.perf_counter() + delay,
                            {"endpoint": endpoint, "attempt": attempt + 1, "delay": delay},
                        )
                    time.sleep(delay)
                    continue
                if status < 200 or status >= 300:
                    text = payload.decode("utf-8", errors="replace")
                    raise RuntimeError(f"TurboOCR HTTP {status}: {text[:500]}")
                parse_start = time.perf_counter()
                data = json.loads(payload.decode("utf-8"))
                if inference_ms is not None:
                    data["_inference_ms"] = inference_ms
                if trace is not None:
                    trace.complete(
                        "turboocr_parse_response",
                        parse_start,
                        time.perf_counter(),
                        {
                            "endpoint": endpoint,
                            "results": len(data.get("results", []))
                            if isinstance(data, dict)
                            else None,
                        },
                    )
                return data
            except (OSError, TimeoutError, http.client.HTTPException, json.JSONDecodeError) as exc:
                last_error = exc
                if trace is not None:
                    trace.complete(
                        "turboocr_http_request",
                        http_start,
                        time.perf_counter(),
                        {
                            "endpoint": endpoint,
                            "attempt": attempt + 1,
                            "request_bytes": len(body),
                            "error": repr(exc),
                        },
                    )
                self.close()
                if attempt >= self.config.retries:
                    break
                time.sleep(self.config.retry_delay * (attempt + 1))
        raise RuntimeError(f"TurboOCR request failed: {last_error}")

    def recognize_file(
        self,
        path: str,
        trace: "TraceRecorder | None" = None,
    ) -> tuple[int, int, list[dict], dict]:
        if self.config.input_mode == "pixels":
            body, width, height, channels = read_image_as_bgr(
                path,
                trace,
                self.config.avif_decoder,
                self.config.imagecodecs_numthreads,
            )
            prepare_start = time.perf_counter()
            headers = {
                "Content-Type": "application/octet-stream",
                "X-Width": str(width),
                "X-Height": str(height),
                "X-Channels": str(channels),
            }
            if trace is not None:
                trace.complete(
                    "turboocr_prepare_pixels",
                    prepare_start,
                    time.perf_counter(),
                    {
                        "width": width,
                        "height": height,
                        "channels": channels,
                        "request_bytes": len(body),
                    },
                )
            data = self._post_json("/ocr/pixels", body, headers, trace)
        else:
            size_start = time.perf_counter()
            width, height = read_image_size(path)
            if trace is not None:
                trace.complete(
                    "turboocr_read_image_size",
                    size_start,
                    time.perf_counter(),
                    {"width": width, "height": height},
                )
            read_start = time.perf_counter()
            body = Path(path).read_bytes()
            if trace is not None:
                trace.complete(
                    "turboocr_read_raw_bytes",
                    read_start,
                    time.perf_counter(),
                    {"request_bytes": len(body)},
                )
            prepare_start = time.perf_counter()
            headers = {"Content-Type": content_type_for_path(path)}
            if trace is not None:
                trace.complete(
                    "turboocr_prepare_raw",
                    prepare_start,
                    time.perf_counter(),
                    {"content_type": headers["Content-Type"], "request_bytes": len(body)},
                )
            data = self._post_json("/ocr/raw", body, headers, trace)
        convert_start = time.perf_counter()
        texts = turbo_results_to_texts(data, self.config.threshold)
        if trace is not None:
            trace.complete(
                "turboocr_convert_results",
                convert_start,
                time.perf_counter(),
                {
                    "raw_results": len(data.get("results", [])) if isinstance(data, dict) else None,
                    "texts": len(texts),
                },
            )
        return width, height, texts, data


def _parse_retry_after(value: str | None, fallback: float) -> float:
    if not value:
        return fallback
    try:
        return max(0.0, float(value))
    except ValueError:
        return fallback


def read_image_size(path: str) -> tuple[int, int]:
    with Image.open(path) as image:
        return image.size


def load_imagecodecs():
    global _IMAGECODECS_IMPORT_ATTEMPTED, _IMAGECODECS_IMPORT_ERROR, _IMAGECODECS_MODULE
    if _IMAGECODECS_IMPORT_ATTEMPTED:
        return _IMAGECODECS_MODULE
    with _IMAGECODECS_LOCK:
        if _IMAGECODECS_IMPORT_ATTEMPTED:
            return _IMAGECODECS_MODULE
        try:
            import imagecodecs

            _IMAGECODECS_MODULE = imagecodecs
            _IMAGECODECS_IMPORT_ERROR = None
        except BaseException as exc:
            _IMAGECODECS_MODULE = None
            _IMAGECODECS_IMPORT_ERROR = exc
        _IMAGECODECS_IMPORT_ATTEMPTED = True
        return _IMAGECODECS_MODULE


def resolve_avif_decoder(path: str, requested: str) -> str:
    if os.path.splitext(path)[1].lower() != ".avif":
        return "pil"
    if requested == "pil":
        return "pil"
    module = load_imagecodecs()
    if module is not None:
        return "imagecodecs"
    if requested == "imagecodecs":
        detail = f": {_IMAGECODECS_IMPORT_ERROR}" if _IMAGECODECS_IMPORT_ERROR else ""
        raise RuntimeError(
            "imagecodecs AVIF decoder requested but imagecodecs is not importable. "
            "Install it with `pip install imagecodecs`."
            f"{detail}"
        )
    return "pil"


def read_image_as_bgr(
    path: str,
    trace: "TraceRecorder | None" = None,
    avif_decoder: str = "auto",
    imagecodecs_numthreads: int = 1,
) -> tuple[bytes, int, int, int]:
    decoder = resolve_avif_decoder(path, avif_decoder)
    if decoder == "imagecodecs":
        return read_avif_as_bgr_imagecodecs(path, trace, imagecodecs_numthreads)
    return read_image_as_bgr_pil(path, trace, decoder)


def read_image_as_bgr_pil(
    path: str,
    trace: "TraceRecorder | None",
    decoder: str,
) -> tuple[bytes, int, int, int]:
    decode_start = time.perf_counter()
    with Image.open(path) as image:
        rgb = image.convert("RGB")
        width, height = rgb.size
        if trace is not None:
            trace.complete(
                "turboocr_decode_image",
                decode_start,
                time.perf_counter(),
                {"width": width, "height": height, "decoder": decoder},
            )
        pack_start = time.perf_counter()
        body = rgb.tobytes("raw", "BGR")
        if trace is not None:
            trace.complete(
                "turboocr_pack_bgr",
                pack_start,
                time.perf_counter(),
                {
                    "width": width,
                    "height": height,
                    "request_bytes": len(body),
                    "decoder": decoder,
                },
            )
        return body, width, height, 3


def read_avif_as_bgr_imagecodecs(
    path: str,
    trace: "TraceRecorder | None",
    numthreads: int,
) -> tuple[bytes, int, int, int]:
    imagecodecs = load_imagecodecs()
    if imagecodecs is None:
        raise RuntimeError("imagecodecs AVIF decoder is not importable")
    encoded = Path(path).read_bytes()
    decode_start = time.perf_counter()
    image = imagecodecs.avif_decode(encoded, numthreads=max(1, numthreads))
    height, width = int(image.shape[0]), int(image.shape[1])
    if trace is not None:
        trace.complete(
            "turboocr_decode_image",
            decode_start,
            time.perf_counter(),
            {
                "width": width,
                "height": height,
                "decoder": "imagecodecs",
                "encoded_bytes": len(encoded),
                "numthreads": max(1, numthreads),
            },
        )
    pack_start = time.perf_counter()
    if image.ndim == 2:
        image = image[:, :, None]
    if image.shape[2] == 1:
        image = image.repeat(3, axis=2)
    elif image.shape[2] >= 3:
        image = image[:, :, :3]
    else:
        raise RuntimeError(f"unsupported AVIF channel count: {image.shape[2]}")
    if image.dtype.name != "uint8":
        if image.dtype.itemsize > 1:
            image = (image >> (8 * (image.dtype.itemsize - 1))).astype("uint8")
        else:
            image = image.astype("uint8")
    body = image[:, :, ::-1].copy().tobytes()
    if trace is not None:
        trace.complete(
            "turboocr_pack_bgr",
            pack_start,
            time.perf_counter(),
            {
                "width": width,
                "height": height,
                "request_bytes": len(body),
                "decoder": "imagecodecs",
            },
        )
    return body, width, height, 3


def content_type_for_path(path: str) -> str:
    ext = os.path.splitext(path)[1].lower()
    return {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".webp": "image/webp",
        ".avif": "image/avif",
        ".bmp": "image/bmp",
        ".tif": "image/tiff",
        ".tiff": "image/tiff",
    }.get(ext, "application/octet-stream")


def turbo_results_to_texts(response: dict, threshold: float) -> list[dict]:
    texts: list[dict] = []
    for item in response.get("results", []):
        text = str(item.get("text", "")).strip()
        try:
            confidence = float(item.get("confidence", 0.0))
        except (TypeError, ValueError):
            confidence = 0.0
        if not text or confidence < threshold:
            continue

        bbox = bbox_from_turbo_box(item.get("bounding_box"))
        if bbox is None:
            continue
        entry = {
            "text": text,
            "confidence": round(confidence, 4),
            "bbox": bbox,
        }
        if isinstance(item.get("bounding_box"), list):
            entry["poly"] = [
                [int(round(float(point[0]))), int(round(float(point[1])))]
                for point in item["bounding_box"]
                if isinstance(point, list) and len(point) >= 2
            ]
        texts.append(entry)
    return texts


def is_fatal_empty_turboocr_response(response: dict) -> bool:
    if not isinstance(response, dict):
        return False
    if response.get("results") != []:
        return False
    inference_ms = response.get("_inference_ms")
    if inference_ms is None:
        return False
    try:
        return float(str(inference_ms).strip()) == 0.0
    except ValueError:
        return False


def bbox_from_turbo_box(box) -> list[int] | None:
    if not isinstance(box, list) or not box:
        return None
    points: list[tuple[float, float]] = []
    if len(box) == 4 and all(isinstance(value, (int, float)) for value in box):
        x1, y1, x2, y2 = [float(value) for value in box]
        points = [(x1, y1), (x2, y2)]
    else:
        for point in box:
            if isinstance(point, list) and len(point) >= 2:
                try:
                    points.append((float(point[0]), float(point[1])))
                except (TypeError, ValueError):
                    continue
    if not points:
        return None
    xs = [point[0] for point in points]
    ys = [point[1] for point in points]
    return [
        int(round(min(xs))),
        int(round(min(ys))),
        int(round(max(xs))),
        int(round(max(ys))),
    ]


def server_ready(base_url: str, timeout: float = 2.0) -> bool:
    url = base_url.rstrip("/") + "/health/ready"
    try:
        with urllib.request.urlopen(url, timeout=timeout) as response:
            return 200 <= response.status < 300
    except (OSError, urllib.error.URLError):
        return False


def wait_for_server(base_url: str, timeout: float) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if server_ready(base_url):
            return True
        time.sleep(2.0)
    return False


def ensure_turboocr_server(args: argparse.Namespace) -> None:
    maybe_rewrite_default_turboocr_port(args)
    if args.turboocr_docker == "never":
        if not server_ready(args.turboocr_url):
            raise RuntimeError(f"TurboOCR is not ready: {args.turboocr_url}")
        return

    if server_ready(args.turboocr_url):
        print(f"TurboOCR ready: {args.turboocr_url}", flush=True)
        return

    docker = shutil.which("docker")
    if docker is None:
        raise RuntimeError("docker executable not found and TurboOCR is not ready")

    if _docker_container_exists(docker, args.turboocr_container):
        print(f"Starting TurboOCR container: {args.turboocr_container}", flush=True)
        _run_checked([docker, "start", args.turboocr_container])
    else:
        print(f"Creating TurboOCR container: {args.turboocr_container}", flush=True)
        _run_checked(_docker_run_command(docker, args))

    print(
        f"Waiting for TurboOCR readiness for up to {args.turboocr_ready_timeout:.0f}s...",
        flush=True,
    )
    if not wait_for_server(args.turboocr_url, args.turboocr_ready_timeout):
        raise RuntimeError(
            "TurboOCR container started but readiness check did not pass. "
            "First TensorRT engine build can take a long time; inspect docker logs."
        )
    print(f"TurboOCR ready: {args.turboocr_url}", flush=True)


def maybe_rewrite_default_turboocr_port(args: argparse.Namespace) -> None:
    if getattr(args, "turboocr_url_explicit", False):
        return
    parsed = urlparse(args.turboocr_url.rstrip("/"))
    host = parsed.hostname or "localhost"
    port = parsed.port or 8000
    if server_ready(args.turboocr_url, timeout=0.5):
        return
    if tcp_port_in_use(host, port) or not tcp_port_available(host, port):
        existing_url = find_ready_alternate_server(parsed.scheme or "http", 18000)
        if existing_url:
            args.turboocr_url = existing_url
            alt_port = urlparse(existing_url).port or 18000
            if args.turboocr_container == DEFAULT_TURBOOCR_CONTAINER:
                args.turboocr_container = f"{DEFAULT_TURBOOCR_CONTAINER}-{alt_port}"
            print(
                f"TurboOCR default port {port} is busy; using ready {args.turboocr_url}",
                flush=True,
            )
            return
        new_port = find_available_port(18000)
        args.turboocr_url = f"{parsed.scheme or 'http'}://localhost:{new_port}"
        if args.turboocr_container == DEFAULT_TURBOOCR_CONTAINER:
            args.turboocr_container = f"{DEFAULT_TURBOOCR_CONTAINER}-{new_port}"
        print(
            f"TurboOCR default port {port} is busy; using {args.turboocr_url}",
            flush=True,
        )


def tcp_port_available(host: str, port: int) -> bool:
    bind_host = "127.0.0.1" if host in {"localhost", "127.0.0.1", "::1"} else host
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            sock.bind((bind_host, port))
        except OSError:
            return False
    return True


def tcp_port_in_use(host: str, port: int) -> bool:
    connect_host = "127.0.0.1" if host in {"localhost", "127.0.0.1", "::1"} else host
    try:
        with socket.create_connection((connect_host, port), timeout=0.5):
            return True
    except OSError:
        return False


def find_available_port(start: int) -> int:
    for port in range(start, start + 1000):
        if not tcp_port_in_use("127.0.0.1", port) and tcp_port_available("127.0.0.1", port):
            return port
    raise RuntimeError("could not find an available TurboOCR port")


def find_ready_alternate_server(scheme: str, start: int) -> str | None:
    for port in range(start, start + 100):
        url = f"{scheme}://localhost:{port}"
        if server_ready(url, timeout=0.5):
            return url
    return None


def _docker_container_exists(docker: str, name: str) -> bool:
    result = subprocess.run(
        [docker, "ps", "-a", "--filter", f"name=^{name}$", "--format", "{{.Names}}"],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return result.returncode == 0 and name in result.stdout.splitlines()


def _docker_run_command(docker: str, args: argparse.Namespace) -> list[str]:
    parsed = urlparse(args.turboocr_url.rstrip("/"))
    host_port = parsed.port or 8000
    cmd = [
        docker,
        "run",
        "-d",
        "--gpus",
        "all",
        "--name",
        args.turboocr_container,
        "-p",
        f"{host_port}:8000",
        "-p",
        f"{args.turboocr_grpc_port}:50051",
        "-v",
        f"{args.turboocr_cache_volume}:/home/ocr/.cache/turbo-ocr",
        "-e",
        f"OCR_LANG={args.turboocr_lang}",
        "-e",
        f"PIPELINE_POOL_SIZE={args.turboocr_pipeline_pool_size}",
        "-e",
        f"DET_MAX_SIDE={args.turboocr_det_max_side}",
    ]
    if args.turboocr_disable_layout:
        cmd.extend(["-e", "DISABLE_LAYOUT=1"])
    if args.turboocr_disable_angle_cls:
        cmd.extend(["-e", "DISABLE_ANGLE_CLS=1"])
    if args.turboocr_trt_opt_level is not None:
        cmd.extend(["-e", f"TRT_OPT_LEVEL={args.turboocr_trt_opt_level}"])
    cmd.append(args.turboocr_image)
    return cmd


def _run_checked(cmd: list[str]) -> None:
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip() or "command failed"
        raise RuntimeError(f"{' '.join(cmd)} failed: {message}")


def get_thread_client(config: TurboOcrConfig) -> TurboOcrClient:
    local = _THREAD_LOCAL
    client = getattr(local, "turboocr_client", None)
    if client is None or getattr(local, "turboocr_config", None) != config:
        client = TurboOcrClient(config)
        local.turboocr_client = client
        local.turboocr_config = config
    return client


_THREAD_LOCAL = threading.local()


class TraceRecorder:
    def __init__(self, trace_tid: str, task: dict, mode: str):
        self.trace_tid = trace_tid
        self.task = task
        self.mode = mode

    def complete(
        self,
        name: str,
        start: float,
        end: float,
        args: dict | None = None,
    ) -> None:
        merged = {
            "page": self.task.get("page_num"),
            "file": os.path.basename(str(self.task.get("target", ""))),
            "mode": self.mode,
        }
        if args:
            merged.update(args)
        trace_writer.TRACE.complete(name, "ocr", start, end, self.trace_tid, merged)


def recognize_page(task: dict, config: TurboOcrConfig, trace_tid: str) -> dict:
    page_num = task["page_num"]
    path = task["target"]
    start = time.perf_counter()
    decode_start = start
    trace = TraceRecorder(trace_tid, task, config.input_mode)
    width = None
    height = None
    texts = []
    raw_response = {}
    try:
        client = get_thread_client(config)
        width, height, texts, raw_response = client.recognize_file(path, trace)
        if is_fatal_empty_turboocr_response(raw_response):
            raise FatalTurboOcrError(
                "TurboOCR returned an empty result with inference_ms=0; "
                "the server is likely poisoned by a CUDA error. "
                f"page={page_num} file={os.path.basename(path)} size={width}x{height}"
            )
        decode_end = time.perf_counter()
        inference_ms = raw_response.get("_inference_ms")

        post_start = time.perf_counter()
        dialogues = ocr_common.group_into_dialogues(texts, width, height)
        post_end = time.perf_counter()
        trace_writer.TRACE.complete(
            "turboocr_postprocess_group_dialogues",
            "ocr",
            post_start,
            post_end,
            trace_tid,
            {"page": page_num, "texts": len(texts), "dialogues": len(dialogues)},
        )
        return {
            "page": page_num,
            "width": width,
            "height": height,
            "dialogues": dialogues,
        }
    finally:
        trace_writer.TRACE.complete(
            "turboocr_request",
            "ocr",
            start,
            time.perf_counter(),
            trace_tid,
            {
                "page": page_num,
                "file": os.path.basename(path),
                "mode": config.input_mode,
                "avif_decoder": config.avif_decoder,
                "width": width,
                "height": height,
                "texts": len(texts),
                "inference_ms": raw_response.get("_inference_ms")
                if isinstance(raw_response, dict)
                else None,
                "decode_and_request_us": int((time.perf_counter() - decode_start) * 1_000_000),
            },
        )


def ocr_work_turbo(
    work_id: str,
    article_dir: str,
    output_dir: str,
    config: TurboOcrConfig,
    request_workers: int,
    progress,
) -> object:
    t0 = time.perf_counter()
    try:
        images = ocr_common.get_sorted_images(article_dir)
        if not images:
            return work_plan.OcrResult(
                work_id=work_id,
                ok=False,
                skipped=False,
                pages=0,
                dialogues=0,
                elapsed=time.perf_counter() - t0,
                error=f"No images found: {article_dir}",
            )

        progress.set_ocr_active(work_id, 0, len(images))
        pages_by_number: dict[int, dict] = {}
        done_count = 0
        tasks = [
            {
                "target": img_path,
                "page_num": page_num,
            }
            for page_num, img_path in images
        ]
        worker_count = max(1, min(request_workers, len(tasks)))
        executor = ThreadPoolExecutor(max_workers=worker_count)
        futures = {
            executor.submit(
                recognize_page,
                task,
                config,
                f"turboocr-worker-{index % worker_count}",
            ): task
            for index, task in enumerate(tasks)
        }
        try:
            for future in as_completed(futures):
                page = future.result()
                pages_by_number[page["page"]] = page
                done_count += 1
                progress.set_ocr_active(work_id, done_count, len(images))
        except FatalTurboOcrError:
            for pending in futures:
                pending.cancel()
            raise
        finally:
            executor.shutdown(wait=False, cancel_futures=True)

        pages = [pages_by_number[page_num] for page_num, _ in images]
        output = {
            "articleId": work_id,
            "totalPages": len(images),
            "threshold": config.threshold,
            "ocrBackend": "turboocr",
            "turboocrInputMode": config.input_mode,
            "avifDecoder": config.avif_decoder,
            "imagecodecsNumthreads": config.imagecodecs_numthreads,
            "pages": pages,
        }
        output_path = ocr_common.save_ocr_result(output, output_dir)
        dialogues = sum(len(page["dialogues"]) for page in pages)
        return work_plan.OcrResult(
            work_id=work_id,
            ok=True,
            skipped=False,
            pages=len(pages),
            dialogues=dialogues,
            elapsed=time.perf_counter() - t0,
            preprocess_elapsed=0.0,
            output_path=output_path,
        )
    except FatalTurboOcrError:
        raise
    except BaseException as exc:
        return work_plan.OcrResult(
            work_id=work_id,
            ok=False,
            skipped=False,
            pages=0,
            dialogues=0,
            elapsed=time.perf_counter() - t0,
            error=str(exc),
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download Hitomi IDs and OCR them through TurboOCR."
    )
    parser.add_argument("count", type=int, nargs="?", default=0)
    parser.add_argument("--target-ids", default=work_plan.TARGET_IDS_PATH)
    parser.add_argument("--ids", nargs="+")
    parser.add_argument("--db-path", default=work_plan.DEFAULT_DB_PATH)
    parser.add_argument("--tmp-dir", default=work_plan.TMP_DIR)
    parser.add_argument("--raw-dir", default=work_plan.RAW_DIR)
    parser.add_argument("--gallery-dl", default="gallery-dl")
    parser.add_argument(
        "--downloader",
        choices=("go",),
        default="go",
        help="Downloader backend. Only go/fast-dl is supported in this package.",
    )
    parser.add_argument("--go-downloader", default=work_plan.GO_DOWNLOADER)
    parser.add_argument("--download-workers", type=int, default=4)
    parser.add_argument("--file-workers", type=int, default=32)
    parser.add_argument("--file-retries", type=int, default=100)
    parser.add_argument("--max-pages", type=int, default=500)
    parser.add_argument(
        "--workers",
        type=int,
        default=8,
        help="Concurrent TurboOCR HTTP requests. Default: 8",
    )
    parser.add_argument(
        "--preprocess-workers",
        type=int,
        default=0,
        help="Compatibility no-op. TurboOCR mode decodes in request workers.",
    )
    parser.add_argument("--ocr-active-works", type=int, default=1)
    parser.add_argument("--threshold", type=float, default=0.5)
    parser.add_argument("--progress-interval", type=float, default=5.0)
    parser.add_argument("--force-download", action="store_true")
    parser.add_argument("--force-ocr", action="store_true")
    parser.add_argument("--keep-empty-tmp", action="store_true")
    parser.add_argument("--failed-ids", default=work_plan.FAILED_IDS_PATH)
    parser.add_argument("--retry-failed", action="store_true")
    parser.add_argument("--trace-file", default=None)
    parser.add_argument("--no-trace", action="store_true")

    parser.add_argument("--turboocr-url", default=DEFAULT_TURBOOCR_URL)
    parser.add_argument(
        "--turboocr-input",
        choices=("pixels", "raw"),
        default="pixels",
        help="Use /ocr/pixels with decoded BGR bytes or /ocr/raw with file bytes.",
    )
    parser.add_argument(
        "--avif-decoder",
        choices=("auto", "pil", "imagecodecs"),
        default="auto",
        help="AVIF decoder for /ocr/pixels mode. auto uses imagecodecs when importable.",
    )
    parser.add_argument(
        "--imagecodecs-numthreads",
        type=int,
        default=1,
        help="Threads per imagecodecs AVIF decode. Keep 1 when using many request workers.",
    )
    parser.add_argument("--turboocr-timeout", type=float, default=300.0)
    parser.add_argument("--turboocr-retries", type=int, default=5)
    parser.add_argument("--turboocr-retry-delay", type=float, default=0.2)
    parser.add_argument(
        "--turboocr-docker",
        choices=("auto", "never"),
        default="auto",
        help="Start a local TurboOCR Docker container when the server is not ready.",
    )
    parser.add_argument("--turboocr-image", default=DEFAULT_TURBOOCR_IMAGE)
    parser.add_argument("--turboocr-container", default=DEFAULT_TURBOOCR_CONTAINER)
    parser.add_argument("--turboocr-cache-volume", default="trt-cache")
    parser.add_argument("--turboocr-lang", default="korean")
    parser.add_argument("--turboocr-pipeline-pool-size", type=int, default=4)
    parser.add_argument("--turboocr-det-max-side", type=int, default=960)
    parser.add_argument("--turboocr-trt-opt-level", type=int, default=3)
    parser.add_argument("--turboocr-ready-timeout", type=float, default=3600.0)
    parser.add_argument("--turboocr-grpc-port", type=int, default=50051)
    parser.add_argument("--turboocr-disable-layout", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--turboocr-disable-angle-cls", action="store_true")
    parser.add_argument("--turboocr-layout", action="store_true")
    parser.add_argument("--turboocr-reading-order", action="store_true")
    parser.add_argument("--turboocr-as-blocks", action="store_true")
    parser.add_argument("--ensure-server-only", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    return parser.parse_args()


def default_trace_file() -> str:
    stamp = time.strftime("%Y%m%d-%H%M%S")
    return os.path.join(SCRIPT_DIR, "traces", f"run-works-turbo-{stamp}.jsonl")


def build_turbo_config(args: argparse.Namespace) -> TurboOcrConfig:
    return TurboOcrConfig(
        base_url=args.turboocr_url,
        input_mode=args.turboocr_input,
        avif_decoder=args.avif_decoder,
        imagecodecs_numthreads=max(1, args.imagecodecs_numthreads),
        threshold=args.threshold,
        timeout=args.turboocr_timeout,
        retries=args.turboocr_retries,
        retry_delay=args.turboocr_retry_delay,
        layout=args.turboocr_layout,
        reading_order=args.turboocr_reading_order,
        as_blocks=args.turboocr_as_blocks,
    )


def _download_with_slot(args, progress, expected_counts, download_slots, work_id: str):
    slot = download_slots.get()
    try:
        return fast_dl_runner.download_work_go(
            work_id,
            args.go_downloader,
            args.gallery_dl,
            args.tmp_dir,
            expected_counts.get(work_id),
            args.force_download,
            args.file_workers,
            args.file_retries,
            args.max_pages,
            progress,
            trace_tid=f"download-go-{slot}",
        )
    finally:
        download_slots.put(slot)


def run_self_test() -> int:
    assert bbox_from_turbo_box([[1.2, 3.9], [9.7, 3.1], [9.2, 8.8], [1.0, 8.1]]) == [1, 3, 10, 9]
    response = {
        "results": [
            {
                "text": " ?덈뀞 ",
                "confidence": 0.95,
                "bounding_box": [[1, 2], [10, 2], [10, 12], [1, 12]],
            },
            {
                "text": "low",
                "confidence": 0.1,
                "bounding_box": [[0, 0], [1, 0], [1, 1], [0, 1]],
            },
        ]
    }
    texts = turbo_results_to_texts(response, 0.5)
    assert texts == [
        {
            "text": "?덈뀞",
            "confidence": 0.95,
            "bbox": [1, 2, 10, 12],
            "poly": [[1, 2], [10, 2], [10, 12], [1, 12]],
        }
    ]
    assert is_fatal_empty_turboocr_response({"results": [], "_inference_ms": "0"})
    assert is_fatal_empty_turboocr_response({"results": [], "_inference_ms": "0.0"})
    assert not is_fatal_empty_turboocr_response({"results": [], "_inference_ms": "12"})
    assert not is_fatal_empty_turboocr_response({"results": [{"text": "ok"}], "_inference_ms": "0"})
    with tempfile.TemporaryDirectory() as tmp_dir:
        image_path = os.path.join(tmp_dir, "sample.png")
        Image.new("RGB", (2, 1), (1, 2, 3)).save(image_path)
        body, width, height, channels = read_image_as_bgr(image_path)
        assert (width, height, channels) == (2, 1, 3)
        assert body == bytes([3, 2, 1, 3, 2, 1])
    assert_avif_decoder_selection_test()
    assert_trace_breakdown_test()
    print("self-test ok")
    return 0


def assert_avif_decoder_selection_test() -> None:
    previous_module = _IMAGECODECS_MODULE
    previous_attempted = _IMAGECODECS_IMPORT_ATTEMPTED
    previous_error = _IMAGECODECS_IMPORT_ERROR
    try:
        globals()["_IMAGECODECS_MODULE"] = None
        globals()["_IMAGECODECS_IMPORT_ATTEMPTED"] = True
        globals()["_IMAGECODECS_IMPORT_ERROR"] = ImportError("test missing imagecodecs")
        assert resolve_avif_decoder("sample.avif", "auto") == "pil"
        try:
            resolve_avif_decoder("sample.avif", "imagecodecs")
        except RuntimeError as exc:
            assert "imagecodecs" in str(exc)
        else:
            raise AssertionError("imagecodecs decoder should require imagecodecs")
        assert resolve_avif_decoder("sample.png", "auto") == "pil"
    finally:
        globals()["_IMAGECODECS_MODULE"] = previous_module
        globals()["_IMAGECODECS_IMPORT_ATTEMPTED"] = previous_attempted
        globals()["_IMAGECODECS_IMPORT_ERROR"] = previous_error


def assert_trace_breakdown_test() -> None:
    class CaptureTrace:
        def __init__(self):
            self.names = []

        def complete(self, name, cat, start, end, tid, args=None):
            self.names.append(name)

        def instant(self, name, cat, tid, args=None):
            self.names.append(name)

        def close(self):
            return

    previous_trace = trace_writer.TRACE
    trace_writer.TRACE = CaptureTrace()
    try:
        with tempfile.TemporaryDirectory() as tmp_dir:
            image_path = os.path.join(tmp_dir, "sample.png")
            Image.new("RGB", (2, 1), (1, 2, 3)).save(image_path)
            config = TurboOcrConfig(
                base_url="http://127.0.0.1:1",
                input_mode="pixels",
                avif_decoder="auto",
                imagecodecs_numthreads=1,
                threshold=0.5,
                timeout=1.0,
                retries=0,
                retry_delay=0.0,
                layout=False,
                reading_order=False,
                as_blocks=False,
            )
            try:
                recognize_page({"target": image_path, "page_num": 1}, config, "self-test")
            except RuntimeError:
                pass
        expected = {
            "turboocr_decode_image",
            "turboocr_prepare_pixels",
            "turboocr_http_request",
        }
        missing = expected - set(trace_writer.TRACE.names)
        assert not missing, f"missing trace spans: {sorted(missing)}"
    finally:
        trace_writer.TRACE = previous_trace


def main() -> int:
    ocr_common.configure_text_output()
    args = parse_args()
    work_plan.FAILED_IDS_PATH = args.failed_ids
    args.turboocr_url_explicit = any(
        item == "--turboocr-url" or item.startswith("--turboocr-url=")
        for item in sys.argv[1:]
    )
    if args.self_test:
        return run_self_test()

    args.workers = max(1, args.workers)
    args.ocr_active_works = max(1, args.ocr_active_works)
    if args.ids and args.count <= 0:
        args.count = len(args.ids)
    maybe_rewrite_default_turboocr_port(args)

    if not args.no_trace:
        trace_writer.TRACE = trace_writer.TraceWriter(args.trace_file or default_trace_file())
        print(f"Chrome trace: {trace_writer.TRACE.path}", flush=True)
        trace_writer.TRACE.instant(
            "trace_start",
            "run",
            "main",
            {
                "backend": "turboocr",
                "count": args.count,
                "workers": args.workers,
                "ocr_active_works": args.ocr_active_works,
                "download_workers": args.download_workers,
                "file_workers": args.file_workers,
                "downloader": args.downloader,
                "turboocr_url": args.turboocr_url,
                "turboocr_input": args.turboocr_input,
                "avif_decoder": args.avif_decoder,
                "imagecodecs_numthreads": max(1, args.imagecodecs_numthreads),
                "turboocr_pipeline_pool_size": args.turboocr_pipeline_pool_size,
                "turboocr_det_max_side": args.turboocr_det_max_side,
            },
        )

    main_t0 = time.perf_counter()
    turbo_config = build_turbo_config(args)
    ensure_turboocr_server(args)
    if args.ensure_server_only:
        trace_writer.TRACE.close()
        return 0

    ids = work_plan.load_target_ids(args.target_ids, args)
    expected_counts = work_plan.load_expected_file_counts(args.db_path, ids)
    os.makedirs(args.tmp_dir, exist_ok=True)
    os.makedirs(args.raw_dir, exist_ok=True)

    bootstrap_t0 = time.perf_counter()
    plan = work_plan.bootstrap_work_plan(ids, args, expected_counts)
    trace_writer.TRACE.complete(
        "bootstrap_work_plan",
        "run",
        bootstrap_t0,
        time.perf_counter(),
        "main",
        {
            "ids": len(ids),
            "raw_skips": len(plan.raw_skips),
            "page_limit_skips": len(plan.page_limit_skips),
            "failed_skips": len(plan.failed_skips),
            "existing_downloads": len(plan.existing_downloads),
            "download_ids": len(plan.download_ids),
        },
    )

    print(f"Target IDs ({len(ids)}): {', '.join(ids)}", flush=True)
    print(f"Raw skips: {len(plan.raw_skips)}", flush=True)
    print(f"Page-limit skips: {len(plan.page_limit_skips)} (> {args.max_pages} pages)", flush=True)
    print(f"Previous download failure skips: {len(plan.failed_skips)}", flush=True)
    print(f"Already downloaded, OCR queued: {len(plan.existing_downloads)}", flush=True)
    print(f"Need download: {len(plan.download_ids)}", flush=True)
    print(f"Downloader backend: {args.downloader}", flush=True)
    print(f"Download work slots: {args.download_workers}", flush=True)
    print(f"Image workers per work: {args.file_workers}", flush=True)
    print(f"TurboOCR URL: {args.turboocr_url}", flush=True)
    print(f"TurboOCR input mode: {args.turboocr_input}", flush=True)
    print(f"AVIF decoder: {args.avif_decoder}", flush=True)
    print(f"imagecodecs numthreads: {max(1, args.imagecodecs_numthreads)}", flush=True)
    print(f"TurboOCR request workers: {args.workers}", flush=True)
    print(f"OCR active works: {args.ocr_active_works}", flush=True)

    if not shutil.which(args.gallery_dl) and not os.path.isfile(args.gallery_dl):
        print(f"Error: gallery-dl not found: {args.gallery_dl}", file=sys.stderr)
        return 127
    if args.downloader == "go" and not os.path.isfile(args.go_downloader):
        print(f"Error: Go downloader not found: {args.go_downloader}", file=sys.stderr)
        return 127

    progress = work_plan.Progress(
        total=len(ids),
        download_total=len(plan.download_ids) + len(plan.existing_downloads),
    )
    download_results = []
    ocr_results = []

    for work_id in plan.raw_skips:
        result = work_plan.OcrResult(
            work_id=work_id,
            ok=True,
            skipped=True,
            pages=0,
            dialogues=0,
            elapsed=0.0,
            output_path=os.path.join(args.raw_dir, f"{work_id}.json"),
        )
        progress.finish_ocr(result)
        ocr_results.append(result)

    for work_id in plan.page_limit_skips:
        result = work_plan.OcrResult(
            work_id=work_id,
            ok=True,
            skipped=True,
            pages=0,
            dialogues=0,
            elapsed=0.0,
            page_limit_skipped=True,
        )
        progress.finish_ocr(result)
        ocr_results.append(result)

    for work_id in plan.failed_skips:
        result = work_plan.OcrResult(
            work_id=work_id,
            ok=True,
            skipped=True,
            pages=0,
            dialogues=0,
            elapsed=0.0,
            error="previous download failure",
        )
        progress.finish_ocr(result)
        ocr_results.append(result)

    if plan.needs_ocr_count == 0:
        print("All selected works are already done, skipped, or over the page limit.")
        work_plan.print_summary([], ocr_results, time.perf_counter() - progress.started_at)
        trace_writer.TRACE.close()
        return 0

    monitor = threading.Thread(
        target=work_plan.progress_printer,
        args=(progress, args.progress_interval),
        daemon=True,
    )
    monitor.start()

    total_t0 = time.perf_counter()
    ready: queue.Queue = queue.Queue()
    downloader = ThreadPoolExecutor(max_workers=args.download_workers)
    ocr_executor = ThreadPoolExecutor(max_workers=args.ocr_active_works)
    download_slots: queue.Queue[int] = queue.Queue()
    for slot in range(args.download_workers):
        download_slots.put(slot)
    download_pending = set()
    ocr_pending = set()

    def finish_ocr_result(ocr_result):
        progress.finish_ocr(ocr_result)
        if ocr_result.ok:
            print(
                f"[{ocr_result.work_id}] TurboOCR done: {ocr_result.pages} pages, "
                f"{ocr_result.dialogues} dialogues, pipeline={ocr_result.elapsed:.2f}s",
                flush=True,
            )
        else:
            print(f"[{ocr_result.work_id}] TurboOCR failed: {ocr_result.error}", flush=True)
            work_plan.write_failure(ocr_result.work_id, "ocr", ocr_result.error)
        ocr_results.append(ocr_result)

    def fill_ocr_slots():
        while len(ocr_pending) < args.ocr_active_works and not ready.empty():
            download = ready.get()
            work_id = download.work_id
            if not download.ok:
                print(f"\n[{work_id}] download failed: {download.error}", flush=True)
                work_plan.write_failure(work_id, "download", download.error)
                result = work_plan.OcrResult(work_id, False, False, 0, 0, 0.0, error=download.error)
                progress.finish_ocr(result)
                ocr_results.append(result)
                continue
            if download.page_limit_skipped:
                print(
                    f"\n[{work_id}] page-limit skip: "
                    f"{download.expected_files} pages > {args.max_pages}",
                    flush=True,
                )
                result = work_plan.OcrResult(
                    work_id=work_id,
                    ok=True,
                    skipped=True,
                    pages=0,
                    dialogues=0,
                    elapsed=0.0,
                    page_limit_skipped=True,
                )
                progress.finish_ocr(result)
                ocr_results.append(result)
                continue
            print(
                f"\n[{work_id}] download "
                f"{'skip' if download.skipped else f'{download.elapsed:.2f}s'} "
                f"files={download.files}/{download.expected_files if download.expected_files is not None else '?'}",
                flush=True,
            )
            future = ocr_executor.submit(
                ocr_work_turbo,
                work_id=work_id,
                article_dir=download.directory,
                output_dir=args.raw_dir,
                config=turbo_config,
                request_workers=args.workers,
                progress=progress,
            )
            ocr_pending.add(future)

    try:
        for download in plan.existing_downloads:
            progress.finish_download(download)
            download_results.append(download)
            ready.put(download)

        for work_id in plan.download_ids:
            future = downloader.submit(
                _download_with_slot,
                args,
                progress,
                expected_counts,
                download_slots,
                work_id,
            )
            download_pending.add(future)

        fill_ocr_slots()
        while download_pending or not ready.empty() or ocr_pending:
            wait_set = download_pending | ocr_pending
            if wait_set:
                done, _ = wait(wait_set, return_when=FIRST_COMPLETED)
            else:
                done = set()
            for future in done:
                if future in download_pending:
                    download_pending.remove(future)
                    result = future.result()
                    download_results.append(result)
                    ready.put(result)
                elif future in ocr_pending:
                    ocr_pending.remove(future)
                    try:
                        ocr_result = future.result()
                    except FatalTurboOcrError as exc:
                        print(f"\nFATAL TurboOCR error: {exc}", flush=True)
                        print("Aborting immediately to avoid writing empty OCR results.", flush=True)
                        os._exit(2)
                    finish_ocr_result(ocr_result)
            fill_ocr_slots()
    except KeyboardInterrupt:
        print("\nInterrupted. Closing pools...", flush=True)
        return 130
    finally:
        progress.stop.set()
        monitor.join(timeout=1)
        downloader.shutdown(wait=False, cancel_futures=True)
        ocr_executor.shutdown(wait=False, cancel_futures=True)
        trace_writer.TRACE.complete(
            "run_works_turbo_total",
            "run",
            main_t0,
            time.perf_counter(),
            "main",
            {"ids": len(ids), "backend": "turboocr"},
        )
        trace_writer.TRACE.close()

    work_plan.print_summary(download_results, ocr_results, time.perf_counter() - total_t0)
    return 0 if all(result.ok or result.skipped for result in ocr_results) else 1


if __name__ == "__main__":
    freeze_support()
    raise SystemExit(main())

