# violet-graph

`violet-graph`는 `violet-search/raw/*.json` OCR 결과에서 작품별 대표 키워드를 추출하고, 그 키워드 CSV를 기반으로 키워드 관계 그래프와 작품 추천 API를 제공하는 Go 도구입니다.

주요 용도는 세 가지입니다.

- `extract`: raw OCR JSON을 읽어 작품별 대표 키워드 CSV를 생성합니다.
- `similar`: 특정 키워드와 같은 작품에 자주 등장하는 관련 키워드를 계산합니다.
- `serve`: 키워드 그래프, 관련 링크, 관련 작품 API와 간단한 내장 웹 UI를 띄웁니다.

## 요구 사항

- Go 1.25 이상
- 입력 데이터: `violet-ocr/raw/*.json`
- 기본 출력 위치: `violet-graph/graph.csv`

이 모듈은 외부 Go 의존성 없이 표준 라이브러리만 사용합니다.

## 빠른 시작

```powershell
cd .\violet-graph
go test ./...
go run . --top-k 100 --load-workers 16
```

인자를 주지 않으면 기본 서브커맨드는 `extract`입니다. 아래 두 명령은 같은 의미입니다.

```powershell
go run . --top-k 100
go run . extract --top-k 100
```

빌드하려면:

```powershell
go build -o violet-graph.exe .
```

## 키워드 추출

전체 raw 폴더에서 작품별 대표 키워드를 추출합니다.

```powershell
.\violet-graph.exe extract `
  --raw ..\violet-ocr\raw `
  --top-k 100 `
  --load-workers 16 `
  --output .\graph.csv
```

빠르게 샘플만 확인하려면 `--limit`을 사용합니다.

```powershell
.\violet-graph.exe extract `
  --raw ..\violet-ocr\raw `
  --limit 500 `
  --top-k 20 `
  --output ..\artifacts\dialogue-explore\work-keywords-go.sample.csv `
  --json-output ..\artifacts\dialogue-explore\work-keywords-go.sample.json `
  --progress-interval 0
```

### 추출 옵션

- `--raw`: raw OCR JSON 디렉터리입니다. 기본값은 `..\raw`입니다.
- `--output`: CSV 출력 경로입니다.
- `--json-output`: 작품별 grouped JSON을 추가로 저장할 경로입니다.
- `--top-k`: 작품마다 남길 대표 키워드 개수입니다. 기본값은 `30`입니다.
- `--load-workers`: raw JSON 로딩/토큰화 병렬 워커 수입니다. 기본값은 `16`입니다.
- `--min-confidence`: 포함할 OCR confidence 최소값입니다. 기본값은 `0.5`입니다.
- `--min-token-len`: 토큰 최소 길이입니다. 기본값은 `2`입니다.
- `--min-tf`: 한 작품 안에서 키워드가 최소 몇 번 나와야 하는지 정합니다. 기본값은 `2`입니다.
- `--min-df`: 전체 작품 기준 최소 document frequency입니다. 기본값은 `1`입니다.
- `--max-df-ratio`: 너무 흔한 단어를 제거하는 비율입니다. 기본값은 `0.4`입니다.
- `--keep-latin`: 기본적으로 제외되는 라틴 토큰을 유지합니다.
- `--limit`: 앞에서부터 N개 raw 파일만 읽습니다. 빠른 실험용입니다.
- `--progress-interval`: N개 파일마다 진행 상황을 출력합니다. `0`이면 끕니다.

### CSV 출력 컬럼

```text
article_id,rank,keyword,score,tf,df,total_pages,dialogue_count,char_count
```

- `article_id`: raw JSON 파일명에서 확장자를 뺀 작품 ID입니다.
- `rank`: 해당 작품 안에서의 키워드 순위입니다.
- `keyword`: 대표 키워드입니다.
- `score`: TF-IDF 계열 점수입니다.
- `tf`: 해당 작품에서 키워드가 등장한 횟수입니다.
- `df`: 전체 작품 중 해당 키워드가 등장한 작품 수입니다.
- `total_pages`: 작품 페이지 수입니다.
- `dialogue_count`: OCR 대사 수입니다.
- `char_count`: OCR 대사 글자 수입니다.

## 관련 키워드 찾기

`similar`는 `extract`로 만든 CSV를 읽고, 특정 키워드와 같은 작품에 같이 나온 키워드를 점수화합니다.

```powershell
.\violet-graph.exe similar `
  --input .\graph.csv `
  --query 키워드A `
  --top-n 30
```

부분어를 포함하는 키워드를 하나의 query 묶음으로 확장할 수도 있습니다.

```powershell
.\violet-graph.exe similar `
  --input .\graph.csv `
  --query 키워드 `
  --expand contains `
  --show-query-terms `
  --top-n 30
```

결과를 CSV 파일로 저장하려면:

```powershell
.\violet-graph.exe similar `
  --input .\graph.csv `
  --query 키워드A `
  --output ..\artifacts\dialogue-explore\similar-키워드A.csv
```

주요 옵션:

- `--input`: `extract`가 만든 키워드 CSV입니다.
- `--query`: 기준 키워드입니다. 첫 번째 위치 인자로도 줄 수 있습니다.
- `--expand`: `none` 또는 `contains`입니다.
- `--show-query-terms`: 확장된 query term 목록을 CSV에 포함합니다.
- `--top-n`: 출력할 관련 키워드 수입니다.
- `--min-cooccur`: 최소 동시 등장 작품 수입니다.
- `--auto-min-cooccur`: 너무 넓은 query에서 최소 동시 등장 기준을 자동으로 올립니다.
- `--min-keyword-df`: 후보 키워드의 최소 작품 등장 수입니다.
- `--output`: 결과 CSV 출력 경로입니다. 없으면 stdout으로 출력합니다.

## 그래프 서버

`serve`는 CSV를 메모리에 올리고 HTTP API와 내장 UI를 제공합니다.

```powershell
.\violet-graph.exe serve `
  --input .\graph.csv `
  --host 127.0.0.1 `
  --port 8787
```

브라우저에서 확인:

```text
http://127.0.0.1:8787
```

`violet-web`에서 같은 서버를 사용하려면 설정의 keyword graph 서버 URL에 아래 값을 넣으면 됩니다.

```text
http://127.0.0.1:8787
```

### API

키워드 그래프:

```text
GET /api/graph?query=키워드&expand=contains&depth=2&topN=20&minScore=0&minCooccur=5&minKeywordDF=5&maxNodes=250
```

관련 링크:

```text
GET /api/links?keywords=키워드A,키워드B&minKeywordDF=5&limit=50
```

관련 작품:

```text
GET /api/works?mode=selected&keywords=키워드A,키워드B&match=soft&limit=100
```

주요 파라미터:

- `query`: 그래프 탐색을 시작할 키워드입니다. `/api/graph`, `/api/works?mode=graph`에서 사용합니다.
- `keywords`: 사용자가 직접 선택한 키워드 목록입니다. 콤마로 구분합니다.
- `mode`: 작품 추천 방식입니다. `graph` 또는 `selected`입니다.
- `match`: 선택 키워드 매칭 방식입니다. `soft` 또는 `all`입니다.
- `expand`: query 확장 방식입니다. `none` 또는 `contains`입니다.
- `depth`: 그래프 확장 깊이입니다.
- `topN`: 각 노드에서 가져올 관련 키워드 수입니다.
- `minScore`: 그래프 edge 최소 점수입니다.
- `minCooccur`: 최소 동시 등장 작품 수입니다.
- `autoMinCooccur`: 넓은 query에서 `minCooccur`를 자동 보정할지 정합니다.
- `minKeywordDF`: 후보 키워드가 등장해야 하는 최소 작품 수입니다.
- `maxNodes`: 그래프 노드 상한입니다. 서버는 최대 `2000`으로 제한합니다.
- `limit`: 응답 결과 개수입니다. 서버는 최대 `200`으로 제한합니다.

## top-k 선택 기준

`similar`와 `serve`는 추출된 CSV에 남아 있는 대표 키워드만 보고 계산합니다. 그래서 `extract --top-k` 값이 너무 작으면 희귀한 키워드가 CSV에 남지 않아 검색 결과가 빈약할 수 있습니다.

- `--top-k 100`: 탐색 범위가 넓어지고 희귀 query 대응이 좋아집니다. 일반적인 실험용으로 무난합니다.
- `--top-k 200`: 넓게 훑기 좋지만 노이즈도 늘어납니다. 후처리 필터가 더 중요합니다.

그래프 탐색 품질이 부족하면 먼저 `--top-k 100`으로 CSV를 다시 만든 뒤 `similar` 또는 `serve`의 `--input`을 새 CSV로 바꿔보는 것이 좋습니다.

## 테스트

```powershell
cd .\violet-graph
go test ./...
```

테스트는 키워드 추출, 유사 키워드 계산, 그래프 생성, `/api/graph`, `/api/links`, `/api/works` 핸들러 동작을 확인합니다.
