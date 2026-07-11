# fast-hsync

Hitomi/ExHentai 메타데이터를 로컬 SQLite DB(`data.db`)에 동기화하는 Go 도구입니다.

## 준비

- Go 1.25 이상
- SQLite DB
  - 기본 파일명은 `data.db`입니다.
  - 기존 레코드가 있으면 DB의 최대 `Id` 주변을 동기화합니다.
  - 빈 DB에서 처음 시작할 때는 `--latest-id`로 기준 ID를 지정하거나 `--start-id`/`--end-id`로 전체 범위를 지정해야 합니다.

## 설치 및 빌드

```powershell
cd .\fast-hsync
go mod download
go build -o fast-hsync.exe .
```

## 기본 실행

```powershell
.\fast-hsync.exe
```

기본 실행은 현재 폴더의 `data.db`를 사용합니다.

다른 DB 파일을 사용하려면 첫 번째 위치 인자로 넘깁니다.

```powershell
.\fast-hsync.exe C:\path\to\data.db
```

빈 DB에서 처음 시작하는 경우:

```powershell
.\fast-hsync.exe data.db --latest-id=3000000
```

`--latest-id`는 처음 스캔할 기준 Hitomi ID입니다. 이 값 기준으로 앞뒤 약 1만 개씩, 총 약 2만 개 범위를 확인합니다. 한 번 데이터가 들어간 뒤에는 DB의 최대 `Id`를 자동으로 사용하므로 보통 다시 지정하지 않아도 됩니다.

0부터 4,000,000까지 전체 초기 스캔을 하고 싶으면 명시 범위를 사용합니다.

```powershell
.\fast-hsync.exe data.db --start-id=0 --end-id=4000000
```

`--end-id`는 포함되지 않는 끝값입니다. 위 명령은 `0`부터 `3,999,999`까지 확인합니다. 요청 수가 400만 개라 시간이 오래 걸리고 대상 서버에도 부하가 큽니다.

## 옵션

```powershell
.\fast-hsync.exe [DB_PATH] [OPTIONS]
```

| 옵션 | 설명 |
| --- | --- |
| `-f`, `--force` | 이미 DB에 있는 Hitomi ID도 다시 다운로드합니다. 기본값은 기존 ID를 건너뜁니다. |
| `-q`, `--quiet` | 요청별 진행률 출력은 숨기고 단계별 요약과 오류만 출력합니다. |
| `--with-exh` | ExHentai 목록도 함께 동기화하고 Hitomi 레코드와 병합합니다. |
| `--latest-id=N` | DB가 비어 있을 때 첫 동기화 기준 ID를 지정합니다. `--latest-id N` 형식도 가능합니다. |
| `--start-id=N` | 다운로드할 Hitomi gallery block 시작 ID를 지정합니다. |
| `--end-id=N` | 다운로드할 Hitomi gallery block 끝 ID를 지정합니다. 이 값은 포함되지 않습니다. |

예시:

```powershell
.\fast-hsync.exe data.db --force
.\fast-hsync.exe data.db --quiet
.\fast-hsync.exe data.db --with-exh
.\fast-hsync.exe data.db --force --with-exh
.\fast-hsync.exe data.db --latest-id=3000000
.\fast-hsync.exe data.db --start-id=0 --end-id=4000000
```

## ExHentai 동기화

`--with-exh`를 쓰면 ExHentai 일반 목록과 expunged 목록을 읽어서 다음 정보를 보강합니다.

- `EHash`
- `Uploader`
- `Published`
- `Files`
- `Class`
- ExHentai에만 있는 항목(`ExistOnHitomi = 0`)

ExHentai 쿠키는 `COOKIE` 환경변수에서 읽습니다.

```powershell
$env:COOKIE = "ipb_member_id=...; ipb_pass_hash=...; igneous=..."
.\fast-hsync.exe data.db --with-exh
```

## 실행 중 동작

1. DB에서 현재 최대 `Id`를 읽습니다.
2. 기본값은 `latest_id - 10000`부터 약 2만 개 범위의 Hitomi gallery block을 다운로드합니다. `--start-id`/`--end-id`를 지정하면 그 범위를 그대로 사용합니다.
3. 새 항목 또는 변경된 항목만 DB에 upsert합니다.
4. FTS 테이블이 없으면 전체 생성하고, 있으면 변경된 row만 갱신합니다.
5. 변경된 레코드가 있으면 `chunk/data-YYYY-MM-DD_HHMMSS.json` 파일로 저장합니다.

## 생성 파일

- `data.db-wal`, `data.db-shm`: SQLite WAL 모드 보조 파일
- `chunk/data-*.json`: 이번 실행에서 새로 추가되거나 변경된 레코드 목록
- `fast-hsync.exe`: 빌드 결과물

이 파일들은 `.gitignore`에 포함되어 있습니다.

## 테스트

```powershell
go test ./...
```
