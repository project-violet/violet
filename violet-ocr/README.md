# violet-ocr

`fast-dl`로 Hitomi 작품 이미지를 내려받고, TurboOCR 서버로 OCR을 수행해 `raw/`에 JSON 결과를 저장하는 실행 도구입니다.

이 폴더는 TurboOCR 실행 경로만 포함합니다. 기존 PaddleOCR 워커 코드, `download-exp/`, 요약/검색/벡터 저장소 파이프라인, 생성된 `raw/`, `tmp/`, trace 산출물은 포함하지 않았습니다.

## 파일 구성

- `run-works-turbo.py`: 선택한 작품을 다운로드하고 TurboOCR로 페이지 OCR을 수행합니다.
- `start-turboocr.cmd`: 로컬 TurboOCR Docker 컨테이너를 시작하거나 생성한 뒤 준비 상태가 될 때까지 기다립니다.
- `stop-turboocr.cmd`: 실행 중인 `violet-turboocr` 컨테이너를 중지합니다. 컨테이너와 TensorRT 캐시는 삭제하지 않습니다.
- `work_plan.py`: 대상 ID 갱신/선택, 완료된 작업 스킵, 실패 다운로드 기록, 진행률 출력을 담당합니다.
- `fast_dl_runner.py`: 레포 루트의 `../fast-dl/fast-dl.exe` 다운로더를 실행합니다.
- `ocr_common.py`: 이미지 정렬, OCR 결과 저장, 텍스트 박스 그룹핑 헬퍼입니다.
- `trace_writer.py`: Chrome trace JSONL 파일을 기록합니다.
- `fix_ocr_with_vllm.py`: `raw/` JSON의 `pages[*].dialogues[*].text`를 로컬 vLLM EXAONE 서버로 교정해 `raw-fixed/`에 저장합니다.
- `vllm-exaone/`: `fix_ocr_with_vllm.py`에서 사용할 EXAONE 3.5 AWQ vLLM 서버 실행/상태 확인 스크립트입니다.
- `works/target_ids.json`: 기본 대상 ID 목록입니다.

## 대상 ID 갱신

`works/target_ids.json`은 `violet-web/packages/backend/data/data.db`의 `HitomiColumnModel`에서 한국어 작품만 다시 뽑아 갱신할 수 있습니다.

```powershell
python .\work_plan.py refresh-target-ids
```

기본 조건은 `Language = 'korean'`, `ExistOnHitomi = 1`, `Files > 0`이며, `Id` 오름차순으로 저장합니다. 다른 DB를 쓰려면 `--db-path`를 지정합니다.

```powershell
python .\work_plan.py refresh-target-ids --db-path ..\violet-web\packages\backend\data\data.db
```

## 요구 사항

- TurboOCR 서버 실행을 위한 Docker
- Pillow를 사용할 수 있는 Python 환경
- 레포의 `fast-dl/`에서 빌드된 `../fast-dl/fast-dl.exe`
- OCR 교정 도구를 사용할 경우 `http://localhost:8001/v1`에서 응답하는 OpenAI 호환 vLLM 서버

기본 Go 다운로더 경로는 다음과 같습니다.

```powershell
..\fast-dl\fast-dl.exe
```

다른 경로를 쓰려면 `--go-downloader`로 지정하면 됩니다.

## TurboOCR 시작

TurboOCR 서버를 시작하고 `/health/ready`가 응답할 때까지 기다립니다.

```powershell
.\start-turboocr.cmd
```

같은 동작을 Python으로 직접 실행할 수도 있습니다.

```powershell
python .\run-works-turbo.py --ensure-server-only
```

기본값은 다음과 같습니다.

- Docker 이미지: `ghcr.io/aiptimizer/turboocr:v2.3.0`
- 컨테이너 이름: `violet-turboocr`
- 기본 URL: `http://localhost:8000`
- 대체 URL: `8000` 포트가 이미 사용 중이면 `http://localhost:18000`
- TensorRT 캐시 볼륨: `trt-cache`
- OCR 언어: `korean`
- 파이프라인 풀 크기: `4`
- 감지 최대 변 길이: `960`
- 레이아웃 분석은 기본 비활성화
- TensorRT 최적화 레벨: `3`
- 준비 대기 시간: `3600`초

## Docker 설정

`run-works-turbo.py`가 TurboOCR 서버를 자동으로 띄울 때 생성하는 Docker 명령은 다음 구조입니다.

```powershell
docker run -d `
  --gpus all `
  --name violet-turboocr `
  -p 8000:8000 `
  -p 50051:50051 `
  -v trt-cache:/home/ocr/.cache/turbo-ocr `
  -e OCR_LANG=korean `
  -e PIPELINE_POOL_SIZE=4 `
  -e DET_MAX_SIDE=960 `
  -e DISABLE_LAYOUT=1 `
  -e TRT_OPT_LEVEL=3 `
  ghcr.io/aiptimizer/turboocr:v2.3.0
```

각 설정은 `run-works-turbo.py` 옵션으로 바꿀 수 있습니다.

| 설정 | 기본값 | 옵션 |
| --- | --- | --- |
| Docker 이미지 | `ghcr.io/aiptimizer/turboocr:v2.3.0` | `--turboocr-image` |
| 컨테이너 이름 | `violet-turboocr` | `--turboocr-container` |
| HTTP 포트 | `8000:8000` | `--turboocr-url` |
| gRPC 포트 | `50051:50051` | `--turboocr-grpc-port` |
| TensorRT 캐시 볼륨 | `trt-cache:/home/ocr/.cache/turbo-ocr` | `--turboocr-cache-volume` |
| OCR 언어 | `OCR_LANG=korean` | `--turboocr-lang` |
| 파이프라인 풀 크기 | `PIPELINE_POOL_SIZE=4` | `--turboocr-pipeline-pool-size` |
| 감지 최대 변 길이 | `DET_MAX_SIDE=960` | `--turboocr-det-max-side` |
| 레이아웃 비활성화 | `DISABLE_LAYOUT=1` | `--turboocr-disable-layout` / `--no-turboocr-disable-layout` |
| 각도 분류 비활성화 | 기본 미설정 | `--turboocr-disable-angle-cls` |
| TensorRT 최적화 레벨 | `TRT_OPT_LEVEL=3` | `--turboocr-trt-opt-level` |

GPU는 항상 `--gpus all`로 연결합니다. 따라서 Docker Desktop, NVIDIA 드라이버, NVIDIA Container Toolkit 계열 GPU 연동이 동작해야 합니다.

`8000` 포트가 이미 사용 중이고 `--turboocr-url`을 직접 지정하지 않았다면, 실행 스크립트는 `18000`부터 사용 가능한 포트를 찾아 `violet-turboocr-{port}` 형식의 컨테이너 이름을 사용합니다. 이미 준비된 TurboOCR 서버가 `18000`번대에서 발견되면 새 컨테이너를 만들지 않고 그 서버를 사용합니다.

`--turboocr-docker never`를 지정하면 Docker 컨테이너를 만들거나 시작하지 않습니다. 이 경우 `--turboocr-url`의 서버가 이미 준비되어 있어야 합니다.

예시:

```powershell
python .\run-works-turbo.py --ensure-server-only `
  --turboocr-url http://localhost:18000 `
  --turboocr-container violet-turboocr-18000 `
  --turboocr-cache-volume trt-cache-18000 `
  --turboocr-pipeline-pool-size 4 `
  --turboocr-det-max-side 960
```

첫 실행은 Docker 이미지 다운로드와 TensorRT 엔진 빌드 때문에 오래 걸릴 수 있습니다.

준비 상태는 다음 명령으로 확인할 수 있습니다.

```powershell
curl http://localhost:8000/health/ready
curl http://localhost:18000/health/ready
docker ps --filter "name=violet-turboocr"
```

시작 스크립트에 TurboOCR 옵션을 그대로 넘길 수 있습니다.

```powershell
.\start-turboocr.cmd --turboocr-url http://localhost:18000 --turboocr-pipeline-pool-size 4
```

## OCR 실행

`works/target_ids.json`의 마지막 `N`개 ID를 처리합니다.

```powershell
python .\run-works-turbo.py 100
```

ID를 직접 지정할 수도 있습니다.

```powershell
python .\run-works-turbo.py --ids 1234567 2345678
```

기본 배치 실행 예시는 다음과 같습니다.

```powershell
python.exe .\run-works-turbo.py 5000 `
  --download-workers 8 `
  --file-workers 32 `
  --workers 64 `
  --ocr-active-works 1
```

출력 경로는 다음과 같습니다.

- `tmp/{work_id}/`: 다운로드된 페이지 이미지
- `raw/{work_id}.json`: OCR 결과
- `traces/run-works-turbo-*.jsonl`: Chrome trace 출력. `--no-trace`를 쓰면 생성하지 않습니다.
- `works/failed_ids.jsonl`: 다운로드/OCR 실패 기록

기본적으로 이미 `raw/{work_id}.json`이 있으면 스킵합니다. 다시 OCR하려면 `--force-ocr`를 사용합니다. 이미 완성된 다운로드도 기본적으로 스킵하며, 다시 다운로드하려면 `--force-download`를 사용합니다.

## vLLM OCR 교정

`fix_ocr_with_vllm.py`는 TurboOCR 결과 JSON을 읽어 텍스트만 교정한 뒤 `raw-fixed/`에 씁니다. 기본 모델명은 `exaone3.5:7.8b-awq`, 기본 API 주소는 `http://localhost:8001/v1`입니다.

먼저 EXAONE vLLM 서버를 시작합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\vllm-exaone\start.ps1
```

상태 확인과 간단한 채팅 테스트는 다음 명령을 사용합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\vllm-exaone\status.ps1
powershell -ExecutionPolicy Bypass -File .\vllm-exaone\test_chat.ps1
```

한 파일만 교정하려면 다음처럼 실행합니다.

```powershell
python .\fix_ocr_with_vllm.py --file .\raw\1234567.json --output .\raw-fixed
```

여러 파일을 처리할 때는 `--input`, `--limit`, `--workers`를 사용할 수 있습니다.

```powershell
python .\fix_ocr_with_vllm.py --input .\raw --output .\raw-fixed --limit 10 --workers 2
```

저신뢰도 대사만 교정하거나 특정 페이지만 처리할 수도 있습니다.

```powershell
python .\fix_ocr_with_vllm.py --file .\raw\1234567.json --low-confidence-only 0.85 --pages 1,2,5-10
```

## TurboOCR 중지

실행 중인 TurboOCR 컨테이너를 중지합니다.

```powershell
.\stop-turboocr.cmd
```

이 명령은 컨테이너나 TensorRT 캐시를 삭제하지 않습니다. 그래서 다음 시작은 보통 더 빠릅니다.

## 검증

가벼운 검증 명령은 다음과 같습니다.

```powershell
python -m unittest discover -s .\tests
python .\run-works-turbo.py --self-test
python -m compileall -q .
```
