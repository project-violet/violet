# violet-web Architecture Guide

pnpm monorepo: **@violet-web/shared**, **@violet-web/backend**, **@violet-web/frontend**

```
pnpm dev           # frontend + backend 동시 실행
pnpm build         # shared → backend → frontend 순서 빌드
```

---

## packages/shared

공통 타입과 유틸리티. 다른 두 패키지에서 import.

### Types (`src/types/`)

| 파일 | 주요 타입 |
|------|-----------|
| `article.ts` | `Article`, `ArticleSearchResult`, `ImageList`, `TagEntry`, `SuggestionCategory`, `SuggestionResult`, `SuggestionCacheStatus` |
| `bookmark.ts` | `BookmarkGroup`, `BookmarkArticle`, `BookmarkArtist`, `ArtistType` enum, request DTO |
| `history.ts` | `ArticleReadLog`, `ReadLogType` enum, request DTO |

### Utilities (`src/utils/`)

| 함수 | 설명 |
|------|------|
| `parsePipeTags(raw)` | `"\|tag1\|tag2\|"` → `["tag1", "tag2"]` |
| `parseTagTuples(raw)` | `"female:loli\|incest"` → `[{namespace:"female", tag:"loli"}, {namespace:"", tag:"incest"}]` |
| `encodePipeTags(tags)` | 배열 → pipe-delimited 문자열 |
| `ticksToDate(ticks)` | .NET ticks → JS Date |

---

## packages/backend

Express 5 + better-sqlite3. 포트 3001.

### 엔트리

- `index.ts` — 서버 시작, SyncManager 초기화
- `app.ts` — Express 앱 팩토리. CORS, JSON, 로거, 에러 핸들러

### Routes

| 경로 | 파일 | 엔드포인트 |
|------|------|------------|
| `/api/content/search` | `routes/content.ts` | GET — DSL 쿼리 검색 (q, page, pageSize) |
| `/api/content/:id` | | GET — 단일 아티클 |
| `/api/content/suggest` | | GET — 자동완성 (q, limit) |
| `/api/content/suggest/rebuild` | | POST — 캐시 재빌드 |
| `/api/content/suggest/status` | | GET — 캐시 상태 |
| `/api/content/suggest/tag-counts` | | GET — female/male/tag 카운트 맵 (~760KB) |
| `/api/bookmarks/*` | `routes/bookmarks.ts` | 그룹/아티클/아티스트 CRUD |
| `/api/history/*` | `routes/history.ts` | 읽기 기록 CRUD + 페이지네이션 |
| `/api/proxy/image` | `routes/proxy.ts` | GET — 이미지 프록시 (CORS 우회) |
| `/api/proxy/gallery/:id` | | GET — 갤러리 이미지 URL 리졸브 |
| `/api/proxy/thumbnail/:id` | | GET — 썸네일 URL |
| `/api/sync/*` | `routes/sync.ts` | 동기화 상태/트리거 |

### Services

| 서비스 | 역할 |
|--------|------|
| `content-db.ts` | data.db 읽기 전용 싱글턴 커넥션 (better-sqlite3) |
| `user-db.ts` | user.db 생성/관리. BookmarkGroup, BookmarkArticle, BookmarkArtist, ArticleReadLog 테이블 |
| `query-engine.ts` | 검색 DSL → SQL 변환. `artist:`, `tag:`, `female:`, `male:`, `series:`, `group:`, `lang:`, `type:`, OR, 괄호, 부정(`-`), 페이지 범위, 자유 텍스트 지원 |
| `suggestion-engine.ts` | HitomiColumnModel에서 태그 카운트 집계 → 인메모리 캐시. suggestion-cache.json 파일 저장/로드. `getTagCounts()`로 female/male/tag 서브셋 제공 |
| `image-proxy.ts` | 원격 이미지 fetch (User-Agent, Referer 헤더). 캐시 헤더 설정 |
| `gallery-resolver.ts` | hitomi 갤러리 ID → 이미지 URL 리스트. Node vm으로 스크립트 실행, 30분 캐시 |
| `sync-manager.ts` | 싱글턴. 자동 DB 다운로드 + 30분 주기 청크 동기화 + 7일 풀 리프레시 |

### 환경 변수

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `PORT` | 3001 | 서버 포트 |
| `DATA_DB_PATH` | ./data/data.db | 콘텐츠 DB 경로 |
| `USER_DB_PATH` | ./data/user.db | 사용자 DB 경로 |
| `SYNC_ENABLED` | true | 자동 동기화 |
| `SYNC_INTERVAL_MS` | 1800000 | 동기화 주기 (30분) |
| `SYNC_LANGUAGE` | global | DB 언어 변형 |

---

## packages/frontend

React 19 + Vite 6 + TypeScript. 포트 5173, `/api` → localhost:3001 프록시.

### 라우팅 (`router/index.tsx`)

```
/                 → HomePage        (메인 검색)
/article/:id      → ArticlePage     (아티클 상세)
/viewer/:id       → ViewerPage      (전체화면 뷰어, AppShell 밖)
/bookmarks        → BookmarksPage
/history          → HistoryPage
/settings         → SettingsPage
```

AppShell(Sidebar/BottomNav) 안에 렌더링. ViewerPage만 예외.

### Stores (Zustand, persist)

**`app-store.ts`** (localStorage: `violet-app-settings`)
```
contentLanguage, uiLanguage, themeColor, sidebarCollapsed,
viewMode ('grid'|'detail'), cardMinWidth, scrollMode, tagTranslation
```

**`search-store.ts`** (localStorage: `violet-search`)
```
recentSearches: string[] (최대 20개)
```

**`viewer-store.ts`** (localStorage: `violet-viewer-settings`)
```
viewMode ('vertical'|'horizontal'), pageMode ('scroll'|'paged'),
readDirection ('ltr'|'rtl'), padding, showOverlay,
twoPageMode, coverPageMode ('cover'|'normal'), showSettings
```

**`toast-store.ts`** (인메모리, 3초 자동 소멸)

### API Layer (`api/`)

| 파일 | 함수 |
|------|------|
| `client.ts` | Axios 인스턴스 (baseURL: `/api`, timeout: 30s) |
| `content.ts` | `searchArticles`, `getArticle`, `fetchSuggestions`, `rebuildSuggestionCache`, `getSuggestionCacheStatus`, `fetchTagCounts` |
| `bookmarks.ts` | 그룹/아티클/아티스트 CRUD |
| `history.ts` | `getHistory`, `insertReadLog`, `updateReadLog`, `deleteReadLog` |
| `proxy.ts` | `getProxyImageUrl`, `resolveGallery`, `getThumbnailUrl` |
| `sync.ts` | `getSyncStatus`, `triggerSync`, `triggerFullSync` |

### Hooks (`hooks/`)

**데이터 페칭 (React Query)**

| 훅 | 역할 |
|----|------|
| `useSearch` | 단일 페이지 검색 쿼리 |
| `useInfiniteSearch` | 무한 스크롤 검색 |
| `useArticle(id)` | 단일 아티클 |
| `useImageList(id)` | 갤러리 이미지 리스트 |
| `useSuggestions(input)` | 태그 자동완성 |
| `useReadHistory` / `useInfiniteReadHistory` | 읽기 기록 |
| `useBookmarkGroups`, `useBookmarkArticles`, `useIsBookmarked` | 북마크 |
| `useSyncStatus`, `useTriggerSync`, `useTriggerFullSync` | 동기화 |
| `useSuggestionCacheStatus`, `useRebuildSuggestionCache` | 캐시 관리 |

**뮤테이션**

| 훅 | 역할 |
|----|------|
| `useAddBookmark`, `useRemoveBookmark`, `useToggleBookmark` | 북마크 토글 |
| `useInsertReadLog`, `useUpdateReadLog` | 읽기 기록 기록 |

**커스텀**

| 훅 | 역할 |
|----|------|
| `useTagTranslation` | 한국어 태그 번역 dict (lazy import, 모듈 캐시) |
| `useTagCounts` | female/male/tag 카운트 맵 (한 번 fetch, 모듈 캐시) |
| `useViewer` | 페이지 네비게이션, RTL 지원, 키보드 화살표 |
| `useThumbnail(id)` | 아티클 썸네일 로드 |
| `useLocalSearchState` | 로컬 쿼리 필터링, `/` 키 포커스 |
| `useLocalArticleSearch` | URL 쿼리 파라미터로 아티클 필터 |
| `useLocalSuggestions` | 로컬 태그 매칭 자동완성 |
| `useArticleTagSummary` | 아티클 배열에서 태그 집계 (상위 30개) |
| `useMediaQuery` / `useIsMobile` / `useIsDesktop` | 반응형 |

### Components (`components/`)

**`layout/`** — 앱 프레임
- `AppShell` — Sidebar/BottomNav + 스크롤 위치 복원
- `Sidebar` — 네비게이션, 테마 피커, 접기
- `BottomNav` — 모바일 하단 네비
- `TopBar` — 헤더 바

**`search/`** — 검색 UI
- `SearchBar` — 입력 + 드롭다운 (자동완성/최근 검색), `/` 키 포커스
- `SearchResultGrid` — ArticleCard 그리드
- `ArticleCard` — 썸네일 + 메타데이터 + 태그 칩 (클릭 검색, 한국어 번역, 인기순 정렬)
- `SearchFilters` — 언어 필터 드롭다운
- `TagChips` — 태그 선택 버튼
- `LocalSearchSection` — 북마크/히스토리용 로컬 검색

**`common/`** — 공용
- `LazyImage` — Intersection Observer 지연 로딩 + 에러 재시도
- `LoadingSpinner` — 중앙 스피너
- `Toast` — 토스트 알림
- `InfiniteScroll` — 스크롤 트리거

**`viewer/`** — 이미지 뷰어
- `ViewerContainer` — 모드별 리더 라우팅
- `VerticalReader` — 세로 스크롤
- `HorizontalReader` — 가로 스크롤 (RTL 지원)
- `PagedReader` — 페이지 넘김 + 두 페이지 모드
- `ViewerImage` — 단일 이미지 + 로딩 상태
- `ViewerOverlay` — 컨트롤 오버레이
- `ViewerSettings` / `ViewerSettingsPanel` — 뷰어 설정 패널

**`bookmark/`**
- `AddBookmarkDialog` — 그룹 선택 다이얼로그
- `BookmarkGroupList` — 그룹 선택/편집

**기타**
- `ThemeProvider` — 테마 컬러 CSS 변수 적용
- `DiscordIcon`, `GithubIcon`

### i18n (`i18n/`)

- `config.ts` — i18next + react-i18next, 시스템 언어 자동 감지
- `locales/{en,ko,ja,zh}.json` — 4개 언어 번역 파일
- 키 구조: `settings.*`, `search.*`, `home.*`, `article.*`, `viewer.*`, `nav.*`, `bookmarks.*`, `history.*`, `crop.*`, `bookmark.*`

**중요: 모든 사용자 대면 문자열은 반드시 i18n을 통해 표시해야 합니다.**

- 컴포넌트에서 한국어(또는 다른 언어) 문자열을 직접 하드코딩하지 마세요.
- `useTranslation()` 훅의 `t()` 함수를 사용하세요.
- 새 문자열을 추가할 때는 반드시 4개 언어 파일(en, ko, ja, zh) 모두에 키를 추가하세요.
- toast 메시지, 다이얼로그 텍스트, 버튼 라벨, 안내 문구 등 모든 UI 텍스트에 적용됩니다.

### Data (`data/`)

- `tag-ko.json` — 한국어 태그 번역 (~8000 entries). `useTagTranslation` 훅에서 dynamic import로 lazy load

### Styles

- **CSS Modules**: 컴포넌트별 `*.module.css`
- **전역**: `styles/globals.css` (리셋, 스크롤바), `styles/variables.css` (CSS 커스텀 프로퍼티)
- **테마**: 다크/라이트/시스템 모드 지원, 20가지 액센트 컬러 (CSS 변수)
- **스페이싱**: `--spacing-{xs,sm,md,lg,xl}`
- **반응형**: 700px 기준 모바일/데스크탑

### Theme System

#### CSS Variables

- 새로운 CSS를 작성할 때는 하드코딩된 색상 값 대신 **반드시 CSS 변수**를 사용한다
- `variables.css`에 정의된 시맨틱 변수를 우선적으로 활용한다:
  - `--color-bg`, `--color-bg-elevated`, `--color-bg-hover`
  - `--color-text`, `--color-text-secondary`
  - `--color-primary`, `--color-primary-hover`
  - `--color-border`, `--color-surface`
  - `--color-on-primary`: 액센트 색상 위의 텍스트 (예: 버튼 라벨)
  - `--color-toggle-knob`: 토글 스위치 손잡이 색상
  - `--color-slider-accent`: 슬라이더 액센트 색상 (시스템 테마 대응)
  - Component-specific 변수: `--color-chip-*`, `--color-pagination-*`, `--color-toast-*` 등

#### Light/Dark Mode

- 모든 UI 컴포넌트는 라이트 모드와 다크 모드 **양쪽에서 정상 작동**해야 한다
- 새로운 색상 변수를 추가할 경우, `variables.css`의 `:root`와 `:root[data-theme="light"]` 블록에 모두 정의한다
- 컴포넌트를 개발한 뒤에는 양쪽 테마 모두에서 시각적 확인을 권장한다

#### Viewer Exception

- **뷰어(이미지 리더) 컴포넌트는 항상 다크 테마를 유지**한다
- Viewer 관련 파일(`ViewerContainer`, `HorizontalReader`, `VerticalReader`, `ViewerOverlay`, `ViewerSettingsPanel`, `PageThumbnailDialog`, `CropDialog` 등)의 하드코딩 색상은 의도적이며 변경하지 않는다
- 이미지 위에 표시되는 오버레이 버튼들(`ArticleCard`의 `downloadBtn`, `bookmarkBtn` 등)도 가독성을 위해 고정된 다크 색상을 유지한다

#### Testing

- 라이트/다크/시스템 테마를 전환하며 UI가 올바르게 표시되는지 확인한다
- 시스템 테마 설정을 변경했을 때 자동으로 반영되는지 확인한다 (system 모드)

---

## 주요 아키텍처 패턴

### 상태 관리
- **서버 상태**: React Query (staleTime 5분, retry 1)
- **클라이언트 상태**: Zustand + persist (localStorage)
- **URL 상태**: 검색 쿼리/페이지를 URL 파라미터로 관리

### 데이터 흐름
```
Component → useQuery hook → API function → Axios → Express Route → SQLite
```

### 검색 DSL
```
artist:name                   # 네임스페이스 태그
female:loli male:shota        # 복합 태그
lang:korean type:doujinshi    # 필터
-female:loli                  # 부정
(A OR B) C                    # 논리 연산
page>20 page<=100             # 페이지 범위
자유 텍스트                     # 제목 검색
```

### 이미지 파이프라인
1. gallery-resolver가 hitomi 스크립트 실행하여 URL 생성
2. 모든 이미지는 백엔드 프록시 경유 (CORS/핫링크 우회)
3. 프론트에서 Intersection Observer로 지연 로딩
4. 썸네일 30분 인메모리 캐시

### DB 전략
- **data.db** (콘텐츠): 읽기 전용, 클라우드 동기화 (청크 + 7일 풀 리프레시)
- **user.db** (사용자): 로컬 SQLite, 북마크/읽기 기록

---

## 파일/네이밍 컨벤션

| 항목 | 패턴 | 예시 |
|------|------|------|
| 컴포넌트 | PascalCase `.tsx` | `ArticleCard.tsx` |
| 훅 | `use[Feature].ts` | `useTagTranslation.ts` |
| 스토어 | `[feature]-store.ts` | `app-store.ts` |
| CSS 모듈 | `[Component].module.css` | `ArticleCard.module.css` |
| API | `[resource].ts` | `content.ts` |
| 라우트(백) | `[resource].ts` | `content.ts` |
| 서비스 | `[feature].ts` (kebab-case) | `suggestion-engine.ts` |

---

## 주요 의존성

| 패키지 | 프론트엔드 | 백엔드 |
|--------|-----------|--------|
| 프레임워크 | React 19 | Express 5 |
| 빌드 | Vite 6 | tsx 4 |
| DB | — | better-sqlite3 11 |
| 상태 | Zustand 5, React Query 5 | — |
| HTTP | Axios 1.7 | — |
| i18n | i18next 25 | — |
| 라우팅 | React Router 7 | — |
| 아이콘 | lucide-react | — |
