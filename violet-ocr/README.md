# violet-ocr

TurboOCR server runner for downloading Hitomi works with `fast-dl` and writing OCR JSON files to `raw/`.

This package intentionally contains only the TurboOCR path. The older PaddleOCR worker code, `download-exp/`, summary/search/vector-store pipeline, generated `raw/`, `tmp/`, and trace artifacts are not included.

## Files

- `run-works-turbo.py`: downloads selected works and OCRs their pages through TurboOCR.
- `start-turboocr.cmd`: starts or creates the local TurboOCR Docker container and waits until it is ready.
- `stop-turboocr.cmd`: stops running `violet-turboocr` containers without deleting the container or TensorRT cache.
- `work_plan.py`: selects target IDs, skips completed work, tracks failed downloads, and reports progress.
- `fast_dl_runner.py`: invokes the repository-level `../fast-dl/fast-dl.exe` downloader.
- `ocr_common.py`: image ordering, OCR result saving, and text-box grouping helpers.
- `trace_writer.py`: Chrome trace JSONL writer used by the runner.
- `works/target_ids.json`: default target ID list.

## Requirements

- Docker, for the TurboOCR server.
- Python with Pillow available.
- `../fast-dl/fast-dl.exe`, built from the repository's `fast-dl/` directory.

The default Go downloader path is:

```powershell
..\fast-dl\fast-dl.exe
```

Override it with `--go-downloader` if needed.

## Start TurboOCR

Start the TurboOCR server and wait until `/health/ready` responds:

```powershell
.\start-turboocr.cmd
```

Equivalent Python command:

```powershell
python .\run-works-turbo.py --ensure-server-only
```

Defaults:

- Docker image: `ghcr.io/aiptimizer/turboocr:v2.3.0`
- Container name: `violet-turboocr`
- Default URL: `http://localhost:8000`
- Fallback URL: `http://localhost:18000` when port `8000` is already in use
- TensorRT cache volume: `trt-cache`
- OCR language: `korean`
- Pipeline pool size: `4`
- Detection max side: `960`
- Layout disabled by default
- TensorRT optimization level: `3`
- Readiness timeout: `3600` seconds

The first run can take a long time because Docker may need to pull the image and build TensorRT engines.

Check readiness manually:

```powershell
curl http://localhost:8000/health/ready
curl http://localhost:18000/health/ready
docker ps --filter "name=violet-turboocr"
```

Pass TurboOCR options through the start script:

```powershell
.\start-turboocr.cmd --turboocr-url http://localhost:18000 --turboocr-pipeline-pool-size 4
```

## Run OCR

Process the last `N` IDs from `works/target_ids.json`:

```powershell
python .\run-works-turbo.py 100
```

Process explicit IDs:

```powershell
python .\run-works-turbo.py --ids 1234567 2345678
```

Useful options:

```powershell
python .\run-works-turbo.py 100 `
  --download-workers 4 `
  --file-workers 32 `
  --workers 8 `
  --ocr-active-works 1
```

Outputs:

- `tmp/{work_id}/`: downloaded page images
- `raw/{work_id}.json`: OCR result
- `traces/run-works-turbo-*.jsonl`: Chrome trace output unless `--no-trace` is used
- `works/failed_ids.jsonl`: download/OCR failures

The runner skips existing `raw/{work_id}.json` unless `--force-ocr` is passed. It skips already complete downloads unless `--force-download` is passed.

## Stop TurboOCR

Stop running TurboOCR containers:

```powershell
.\stop-turboocr.cmd
```

This does not delete the container or TensorRT cache, so later starts are usually faster.

## Validation

Run the lightweight checks:

```powershell
python -m unittest discover -s .\tests
python .\run-works-turbo.py --self-test
python -m compileall -q .
```
