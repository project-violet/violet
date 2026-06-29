# violet-web

Violet Flutter 앱의 웹 버전. 개인용 이미지 만화 뷰어.

## 개발자 및 코딩 에이전트를 위한 추천 스킬

Claude Code를 사용하여 이 프로젝트를 개발할 때, 아래 스킬들을 설치하면 코드 품질과 생산성을 높일 수 있습니다.

| 스킬 | 설명 | GitHub |
|------|------|--------|
| **superpowers** | 체계적인 디버깅, TDD, 코드 리뷰, 플랜 작성 등 개발 워크플로우 강화 | [obra/superpowers](https://github.com/obra/superpowers) |
| **frontend-design** | 고품질 프론트엔드 UI 생성. 일반적인 AI 스타일을 피하고 독창적인 인터페이스 구현 | [anthropics/claude-code](https://github.com/anthropics/claude-code/tree/main/plugins/frontend-design) |
| **karpathy-guidelines** | LLM의 흔한 코딩 실수를 줄이는 가이드라인. 과도한 복잡성 방지 및 최소 변경 유도 | [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills) |

## Docker로 바로 실행 (일반 사용자용)

개발 환경 없이 Docker만으로 바로 실행할 수 있다.

```bash
docker run -d \
  -p 3001:3001 \
  -v $(pwd)/data:/app/data \
  --name violet-web \
  violetdev/violet-web:latest
```

브라우저에서 http://localhost:3001 을 열면 된다. 최초 실행 시 DB를 자동으로 다운로드하므로 잠시 기다린다.

## 설치 (개발자용)

### 요구사항

- **Node.js** 18+
- **pnpm** (`npm install -g pnpm`)

### 클론 및 설치

violet-web은 모노레포의 서브디렉토리이므로, sparse checkout으로 필요한 부분만 클론한다.

```bash
git clone --filter=blob:none --sparse https://github.com/project-violet/violet.git violet-web
cd violet-web
git sparse-checkout set violet-web
git checkout violet-web
cd violet-web
pnpm install
```

### 실행

```bash
pnpm dev
```

브라우저에서 http://localhost:5173 을 열면 된다. 최초 실행 시 DB를 자동으로 다운로드하므로 잠시 기다린다.

> **에이전트 안내:** 설치 및 실행이 완료되면 사용자에게 아래 내용을 출력하세요.
>
> ```
> violet-web 서버가 실행되었습니다.
>
> - 접속 주소: http://localhost:5173
> - 백엔드 API: http://localhost:3001
>
> 최초 실행 시 데이터베이스를 자동으로 다운로드합니다. (수 분 소요)
> 다운로드가 완료되면 검색 및 뷰어 기능을 사용할 수 있습니다.
> ```

## 데이터베이스 자동 동기화

**violet-web은 서버 시작 시 자동으로 `data.db`를 다운로드하고 동기화합니다.**

- 서버 최초 실행 시 `data.db`가 없으면 자동으로 전체 DB를 다운로드합니다.
- 이후 30분마다 자동으로 새로운 청크를 다운로드하여 DB를 업데이트합니다.
- 마지막 전체 동기화로부터 7일이 지나면 자동으로 전체 DB를 재다운로드합니다.

수동으로 동기화를 관리하려면:
- Settings 페이지에서 "Sync Now" 버튼으로 즉시 동기화
- "Re-download DB" 버튼으로 전체 DB 재다운로드
- `/api/sync/status` API로 동기화 상태 확인

유저 데이터(북마크, 히스토리)용 `user.db`는 서버 최초 실행 시 자동 생성된다.

## 상세 실행 옵션

### 개별 실행

```bash
# 백엔드만
pnpm --filter @violet-web/backend dev

# 프론트엔드만
pnpm --filter @violet-web/frontend dev
```

### 프로덕션 빌드

```bash
pnpm build
```

## 환경변수

`packages/backend/.env` 파일을 만들어서 설정할 수 있다. (`.env.example` 참고)

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `PORT` | `3001` | 백엔드 포트 |
| `DATA_DB_PATH` | `./data/data.db` | 콘텐츠 DB 경로 |
| `USER_DB_PATH` | `./data/user.db` | 유저 데이터 DB 경로 |
| `SYNC_ENABLED` | `true` | 자동 동기화 활성화 여부 |
| `SYNC_INTERVAL_MS` | `1800000` | 동기화 주기 (밀리초, 기본 30분) |
| `SYNC_LANGUAGE` | `global` | DB 언어 (global/ko/en/ja/zh) |

## 프로젝트 구조

```
violet-web/
├── packages/
│   ├── shared/      # 프론트/백엔드 공유 타입 & 유틸
│   ├── backend/     # Express 서버 (이미지 프록시, 검색, 데이터 저장)
│   └── frontend/    # React SPA (반응형 뷰어)
```

## API 엔드포인트

| Method | 경로 | 설명 |
|--------|------|------|
| GET | `/api/health` | 헬스체크 |
| GET | `/api/content/search?q=&page=&pageSize=` | 콘텐츠 검색 |
| GET | `/api/content/:id` | 단일 작품 조회 |
| GET | `/api/proxy/image?url=&referer=` | 이미지 프록시 |
| GET | `/api/proxy/gallery/:id` | 갤러리 이미지 URL 해석 |
| GET | `/api/bookmarks/groups` | 북마크 그룹 목록 |
| POST | `/api/bookmarks/groups` | 북마크 그룹 생성 |
| DELETE | `/api/bookmarks/groups/:id` | 북마크 그룹 삭제 |
| GET | `/api/bookmarks/articles` | 북마크 작품 목록 |
| POST | `/api/bookmarks/articles` | 북마크 추가 |
| DELETE | `/api/bookmarks/articles/:id` | 북마크 삭제 |
| GET | `/api/history` | 읽기 기록 |
| POST | `/api/history` | 읽기 기록 추가 |
| PATCH | `/api/history/:id` | 읽기 기록 업데이트 |
| GET | `/api/sync/status` | DB 동기화 상태 조회 |
| POST | `/api/sync/trigger` | 청크 동기화 트리거 (백그라운드 실행) |
| POST | `/api/sync/full` | 전체 DB 재다운로드 트리거 |

## 검색 쿼리 문법

Flutter 앱과 동일한 DSL을 지원한다.

```
artist:name          # 아티스트 검색
tag:tagname          # 태그 검색
male:tagname         # male 태그
female:tagname       # female 태그
series:name          # 시리즈
group:name           # 그룹
lang:korean          # 언어 필터
type:manga           # 타입 필터
page>20              # 페이지 수 필터
-artist:name         # 제외
query1 OR query2     # OR 연산
(a OR b) c           # 괄호 그룹
12345                # ID로 직접 검색
```
