# fast-dl

Hitomi 작품 파일 목록을 해석하고 다운로드 성능을 측정하는 Go 기반 실험 도구입니다.

## 준비

Go가 설치되어 있어야 합니다.

```powershell
go test ./...
go build .
```

일부 제한된 Windows 환경에서는 Go 캐시를 사용자 폴더에 쓰지 못할 수 있습니다. 그럴 때는 프로젝트 안의 로컬 캐시를 사용합니다.

```powershell
$env:GOTELEMETRY='off'
$env:GOCACHE=(Resolve-Path '.').Path + '\.gocache'
$env:GOPATH=(Resolve-Path '.').Path + '\.gopath'
go test ./...
go build .
```

## 기본 사용법

기본 실행은 여러 작품을 선택해 설정별 다운로드 성능을 측정합니다.

```powershell
.\fast-dl.exe
```

기본값은 `../works/target_ids.json`에서 대상 ID를 읽고, 다운로드 임시 파일은 내부 기본 경로인 `../tmp2-go`에 저장합니다. 각 설정 실행 전 임시 폴더는 삭제됩니다.

## 네트워크 권장 설정

다운로드 속도는 네트워크 경로 영향을 많이 받습니다. 실제 사용 시 Cloudflare WARP를 켠 상태로 함께 사용하는 것을 권장합니다. WARP를 같이 사용하면 Hitomi 이미지 서버까지의 연결이 더 안정적이거나 빠르게 나오는 경우가 많습니다.

## 단일 작품 다운로드

작품 ID 하나만 내려받으려면 `-download-work`를 사용합니다.

```powershell
.\fast-dl.exe -download-work 1234567
```

동시 파일 다운로드 수를 바꾸려면 `-file-workers`를 지정합니다.

```powershell
.\fast-dl.exe -download-work 1234567 -file-workers 32
```

## 벤치마크 옵션

명시한 ID만 대상으로 삼으려면 `-ids`를 사용합니다.

```powershell
.\fast-dl.exe -ids 1234567,2345678 -settings 2x32,4x16
```

자주 쓰는 옵션은 아래와 같습니다.

- `-count`: `target_ids.json`에서 선택할 작품 수입니다. 기본값은 `4`입니다.
- `-target-ids`: 대상 ID JSON 파일 경로입니다. 기본값은 `../works/target_ids.json`입니다.
- `-ids`: 쉼표로 구분한 작품 ID 목록입니다. 지정하면 `target_ids.json` 대신 이 목록을 사용합니다.
- `-settings`: `작품동시수x파일동시수` 형식의 벤치마크 설정 목록입니다. 기본값은 `2x64,2x32,4x16,4x32,1x32,1x64`입니다.
- `-max-pages`: 이 페이지 수를 넘는 작품은 건너뜁니다. 기본값은 `200`입니다.
- `-file-retries`: 이미지 파일별 재시도 횟수입니다. 기본값은 `100`입니다.
- `-keep-tmp`: 설정 사이에 임시 디렉터리를 삭제하지 않습니다.

## Git에 넣지 않는 파일

빌드 산출물과 로컬 캐시는 `.gitignore`로 제외합니다.

- `fast-dl.exe`
- `.gocache/`
- `.gopath/`
- `tmp/`, `tmp2-go/`, `downloads/`
- `*.part`, `*.log`, `*.prof`, `*.pprof`
