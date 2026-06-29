# violet-ocr

`fast-dl`로 Hitomi 작품 이미지를 내려받고, TurboOCR 서버로 OCR을 수행해 `raw/`에 JSON 결과를 저장하는 실행 도구입니다.

이 폴더는 TurboOCR 실행 경로만 포함합니다. 기존 PaddleOCR 워커 코드, `download-exp/`, 요약/검색/벡터 저장소 파이프라인, 생성된 `raw/`, `tmp/`, trace 산출물은 포함하지 않았습니다.

## 파일 구성

- `run-works-turbo.py`: 선택한 작품을 다운로드하고 TurboOCR로 페이지 OCR을 수행합니다.
- `start-turboocr.cmd`: 로컬 TurboOCR Docker 컨테이너를 시작하거나 생성한 뒤 준비 상태가 될 때까지 기다립니다.
- `stop-turboocr.cmd`: 실행 중인 `violet-turboocr` 컨테이너를 중지합니다. 컨테이너와 TensorRT 캐시는 삭제하지 않습니다.
- `work_plan.py`: 대상 ID 선택, 완료된 작업 스킵, 실패 다운로드 기록, 진행률 출력을 담당합니다.
- `fast_dl_runner.py`: 레포 루트의 `../fast-dl/fast-dl.exe` 다운로더를 실행합니다.
- `ocr_common.py`: 이미지 정렬, OCR 결과 저장, 텍스트 박스 그룹핑 헬퍼입니다.
- `trace_writer.py`: Chrome trace JSONL 파일을 기록합니다.
- `works/target_ids.json`: 기본 대상 ID 목록입니다.

## 요구 사항

- TurboOCR 서버 실행을 위한 Docker
- Pillow를 사용할 수 있는 Python 환경
- 레포의 `fast-dl/`에서 빌드된 `../fast-dl/fast-dl.exe`

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

자주 쓰는 실행 옵션 예시는 다음과 같습니다.

```powershell
python .\run-works-turbo.py 100 `
  --download-workers 4 `
  --file-workers 32 `
  --workers 8 `
  --ocr-active-works 1
```

출력 경로는 다음과 같습니다.

- `tmp/{work_id}/`: 다운로드된 페이지 이미지
- `raw/{work_id}.json`: OCR 결과
- `traces/run-works-turbo-*.jsonl`: Chrome trace 출력. `--no-trace`를 쓰면 생성하지 않습니다.
- `works/failed_ids.jsonl`: 다운로드/OCR 실패 기록

기본적으로 이미 `raw/{work_id}.json`이 있으면 스킵합니다. 다시 OCR하려면 `--force-ocr`를 사용합니다. 이미 완성된 다운로드도 기본적으로 스킵하며, 다시 다운로드하려면 `--force-download`를 사용합니다.

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
