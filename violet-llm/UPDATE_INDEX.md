# 작품 추가 및 검색 인덱스 갱신

새 OCR 작품을 추가한 뒤 LLM 검색 서버에 반영하는 전체 절차를 정리한다.

## 전체 흐름

```text
raw-merged-v2에 JSON 추가
  -> Modal H100에서 새 작품 임베딩
  -> 로컬 FP16 통합 인덱스 재생성
  -> FAISS SQ8 검색 인덱스 재생성
  -> compact metadata 재생성
  -> Docker volume 갱신
  -> 검색 서버 재시작 및 확인
```

`run-modal.ps1`은 prepare, 업로드, 임베딩, 다운로드 및 기존 결과와의
병합까지 담당한다. 검색 인덱스 생성과 Docker 반영은 별도로 실행해야 한다.

## 1. OCR JSON 추가

새 작품 JSON을 다음 폴더에 넣는다.

```text
violet-ocr/raw-merged-v2
```

파일 이름의 숫자가 작품 ID이며, 숫자가 큰 작품부터 최신 작품으로 처리된다.
이미 `latest-5000/works`에 결과가 존재하는 작품 ID는 Modal 실행 시 자동으로
건너뛴다.

## 2. 새 작품 임베딩

PowerShell에서 `violet-llm` 폴더로 이동한다.

```powershell
cd C:\Users\rollrat\Desktop\workspace\violet\violet-llm
```

예를 들어 아직 처리되지 않은 작품 100개를 추가하려면 다음과 같이 실행한다.

```powershell
.\run-modal.ps1 -WorkCount 100 -OutputName latest-5000
```

`-WorkCount`는 최종 작품 수가 아니라 이번 실행에서 새로 처리할 작품 수다.
기본 GPU는 H100이며 기본 페이지 설정은 window 3, stride 2다.

실행 과정에는 다음 작업이 모두 포함된다.

1. 처리되지 않은 최신 작품 선택
2. Modal 입력 데이터 준비 및 압축
3. Modal로 업로드
4. H100에서 Qwen3-Embedding-4B 임베딩
5. 결과 압축 및 다운로드
6. 로컬 `outputs/.../latest-5000/works`에 병합

로컬 및 Modal 스트리밍 로그는 다음 폴더에 남는다.

```text
violet-llm/.runtime
```

## 3. FP16 통합 인덱스 재생성

Modal 결과 병합이 끝나면 모든 작품의 FP16 임베딩을 다시 통합한다.

```powershell
python build_index.py --output-name latest-5000 --overwrite
```

주요 결과는 다음과 같다.

```text
index/manifest.json
index/locations.bin
index/embeddings-00000.bin
index/embeddings-00001.bin
...
```

`embeddings-*.bin`은 정확한 FP16 검색, A/B 벤치마크 및 fallback에 사용된다.
기본 운영 검색에서는 직접 사용하지 않는다.

## 4. FAISS SQ8 인덱스 재생성

운영 검색에서 사용하는 압축 벡터 인덱스를 생성한다.

```powershell
python benchmark_search_index.py build `
  --output-name latest-5000 `
  --kind sq8 `
  --overwrite
```

결과 파일:

```text
index/faiss-sq8.index
index/faiss-sq8.json
```

SQ8은 전체 벡터를 검색하지만 FP16보다 메모리 사용량과 검색 시간이 크게
줄어든다. 현재 서버의 기본 검색 backend다.

## 5. Compact metadata 재생성

검색된 벡터에서 작품 ID, 페이지와 대사를 빠르게 가져오기 위한 바이너리
메타데이터를 생성한다.

```powershell
python benchmark_search_index.py build-metadata `
  --output-name latest-5000 `
  --overwrite
```

결과 파일:

```text
index/compact-metadata.json
index/compact-metadata.bin
index/compact-metadata-offsets.bin
```

이 단계는 수많은 `chunks.jsonl` 파일을 읽기 때문에 인덱스 생성 단계 중 가장
오래 걸릴 수 있다. 검색 시에는 개별 JSON 대신 완성된 바이너리를 사용한다.

## 6. Docker 검색 서버에 반영

저장소 루트로 돌아가 완성된 인덱스를 Docker named volume에 복사한다.

```powershell
cd C:\Users\rollrat\Desktop\workspace\violet

docker compose run --rm llm-index-init
docker compose up -d --force-recreate llm-search
```

`llm-index-init`은 로컬의 다음 폴더를 Docker volume로 복사한다.

```text
violet-llm/outputs/Qwen--Qwen3-Embedding-4B/latest-5000/index
```

검색 서버 내부 마운트 경로는 다음과 같다.

```text
/data/Qwen--Qwen3-Embedding-4B/latest-5000/index
```

복사 중에도 기존 검색 컨테이너는 기존 인덱스를 사용한다. 복사가 끝난 다음
`llm-search`를 재생성하면 새 인덱스가 적용된다.

## 7. 반영 확인

검색 서버 상태를 확인한다.

```powershell
Invoke-RestMethod http://127.0.0.1:8788/health
```

정상적인 응답에는 새 작품 수와 다음 backend가 표시되어야 한다.

```json
{
  "status": "ok",
  "backend": "faiss-sq8"
}
```

간단한 검색도 실행한다.

```powershell
$body = @{
  query = "검색할 장면"
  candidate_k = 500
  top_k = 50
  rerank = $true
  include_messages = $false
} | ConvertTo-Json

Invoke-RestMethod -Method Post `
  -Uri http://127.0.0.1:8788/v1/search `
  -ContentType "application/json; charset=utf-8" `
  -Body ([Text.Encoding]::UTF8.GetBytes($body))
```

## 재실행과 실패 처리

- Modal 실행이 실패하면 같은 `-WorkCount`로 다시 실행할 수 있다. 이미 로컬에
  병합된 작품은 자동으로 제외된다.
- Modal 완료 후 인덱스 생성이 실패해도 임베딩 결과는 남아 있으므로
  `run-modal.ps1`을 다시 실행할 필요가 없다.
- `build_index.py`부터 실패한 단계만 `--overwrite`로 다시 실행한다.
- Docker 반영이 실패해도 로컬 인덱스는 유지된다. `llm-index-init`부터 다시
  실행하면 된다.
- 긴 작업 중에도 기존 Docker 검색 서버는 기존 named volume을 사용하므로
  마지막 재시작 전까지 기존 검색을 계속 제공할 수 있다.

## FP16 fallback

SQ8 검색에 문제가 있을 때 다음 환경변수로 기존 FP16 전체 검색을 사용할 수
있다.

```text
VIOLET_LLM_ACCELERATED_INDEX=false
```

FP16 fallback은 `embeddings-*.bin`과 `locations.bin`이 필요하며 SQ8보다 훨씬
느리다. 일반 운영에서는 `faiss-sq8`을 사용한다.
