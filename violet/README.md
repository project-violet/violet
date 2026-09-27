# Violet 앱 (Tauri 2)

`violet-web`의 React 화면을 소스 그대로 사용하고, 앱 내부 기능은 Rust + SQLite로 실행한다. Express·Node 서버를 실행하거나 포트를 열지 않는다. macOS Apple Silicon 앱과 iOS/iPadOS Apple Silicon 시뮬레이터용 `.app` 빌드를 확인했다.

## 구조

```text
violet/                       # 저장소 루트
├── violet-web/
│   └── packages/
│       ├── frontend/         # 웹과 앱이 공유하는 화면·스타일·상태·API 인터페이스
│       ├── shared/           # 공통 타입
│       └── backend/          # 기존 웹 Express 서버
└── violet/                   # 이 디렉터리
    ├── src/main.tsx          # 앱 전용 진입점 및 플랫폼 주입
    ├── src/NativeSetup.tsx   # 첫 DB 다운로드·가져오기
    ├── src/platform/        # 기존 API 계약을 Tauri IPC로 변환
    └── src-tauri/src/       # SQLite·이미지·다운로드·DB 가져오기
```

웹은 기존 `/api` HTTP 경로를 계속 사용한다. 앱은 공유 Axios 인스턴스에 어댑터를 주입해 Rust 명령을 호출한다. 검색 DSL → SQL 변환도 기존 웹 백엔드의 순수 함수를 공유한다. 앱 전용 코드는 웹의 빌드 의존성에 들어가지 않는다.

공통 화면 수정은 `violet-web/packages/frontend`에서, OS·파일·앱 기능은 이 디렉터리에서 한다. 앱이 지원하는 메뉴는 플랫폼 설정으로 걸러낸다. 기존 웹 서버와 앱의 사용자 데이터는 별개다.

앱의 뷰어는 브라우저의 DOM Fullscreen API 대신 iOS 네이티브 몰입 모드를
사용한다. 기본으로 켜진 뷰어 전체화면 설정에 따라 상태바를 숨기고 홈
인디케이터 자동 숨김을 요청하며 이미지가 화면 가장자리까지 표시되게 한다.
홈 인디케이터의 실제 표시 시점은 iOS가 결정한다. 뷰어를 나가면 상태바와
일반 화면의 여백을 복원한다. WebKit의 출처 안내 배너는 요청하지 않으며
일반 웹의 전체화면 동작은 유지한다. 현재 네이티브 몰입 모드는 iOS만 지원한다.

## macOS 실행과 빌드

필요한 도구: Node.js 22 이상, pnpm, Rust stable, Xcode Command Line Tools. `rust-toolchain.toml`은 이 앱에만 stable을 선택하며 전역 기본 툴체인을 바꾸지 않는다.

저장소 루트에서 최초 설치:

```sh
cd violet-web
pnpm install
cd ../violet
npm ci
```

이 디렉터리에서:

```sh
npm run dev        # Vite + Tauri 개발 창
npm run build:mac  # macOS .app
npm test
cargo test --manifest-path src-tauri/Cargo.toml --locked
```

결과: `src-tauri/target/release/bundle/macos/Violet.app`. 현재 빌드는 개발용이며 배포용 Developer ID 서명·공증은 구성하지 않았다. DB는 앱 번들에 포함하지 않는다.

## DB 준비

첫 화면에서 **DB 다운로드** 또는 **기존 DB 가져오기**를 선택한다.

- 다운로드 원본: [2026-07-05 공유 폴더](https://drive.google.com/drive/folders/1jCFskVN_Z6O3a9ayIMoWs5X11_KIK2dt)의 `article-db.zip` (약 866MB, 압축 해제 약 2.2GB).
- 모든 언어가 포함된다. 언어별 검색은 기존 화면의 필터를 사용한다.
- `.db`, `.sqlite`, `.sqlite3`, `.zip`을 가져올 수 있다. ZIP에는 `data.db`가 하나 있어야 한다.
- 다운로드/가져오기 후 무결성을 검사하고 검색 인덱스를 생성하므로 수 GB의 여유 공간과 처리 시간이 필요하다.
- 준비가 성공한 뒤에만 기존 콘텐츠 DB를 교체한다. 북마크·읽기 기록은 별도 `user.db`에 보존한다. SQLite 파일 가져오기는 WAL의 커밋된 내용도 포함하는 사본을 만들며 원본을 변경하지 않는다.
- Drive 다운로드 제한 등이 생기면 브라우저에서 ZIP을 내려받아 가져올 수 있다.

macOS 저장 위치: `~/Library/Application Support/dev.violet.app/`. 콘텐츠 `data.db`, 사용자 `user.db`, `downloads/`, 이미지 캐시가 이곳에 저장된다. 기존 웹의 `data.db`·`user.db`는 자동으로 이동하지 않는다.

현재 다운로드는 위 날짜의 고정 스냅샷이다. 설정의 동기화 버튼도 같은 스냅샷 전체를 다시 받는다. 주기적 증분 동기화는 아직 연결하지 않았다. 새 스냅샷은 `src-tauri/src/sync.rs`의 다운로드 URL을 갱신한다. 만료된 기존 `syncversion.txt` 주소는 앱에서 사용하지 않는다.

## 현재 범위

검색·태그 자동완성·상세·이미지 뷰어·북마크·로컬 잘라낸 북마크·읽기 기록·다운로드를 위한 네이티브 API를 구현했다. 원격 이미지 해석은 외부 서비스의 현재 스크립트와 네트워크 가용성에 의존한다. 다운로드한 콘텐츠는 기기 저장소에서 읽는다.

AI/LLM, 대사 검색, 그래프·분석, 외부 사용자 북마크 집계는 아직 앱에 이식하지 않았다. 해당 메뉴는 숨기며 미지원 API는 명시적인 오류를 반환한다. 일부 공유 설정/버튼은 남아 있으므로 웹의 모든 기능이 동작하는 버전은 아니다. 다운로드 도중 앱을 종료하면 다음 실행에서 실패로 표시하고 재시도할 수 있다. 모바일 백그라운드 다운로드는 별도 구현이 필요하다.

## iOS / iPadOS 시뮬레이터 빌드

필요한 도구: macOS의 정식 Xcode와 iOS 시뮬레이터 런타임, XcodeGen,
CocoaPods, libimobiledevice. iPhone과 iPad는 같은 iOS 런타임을 사용하며
watchOS·tvOS·visionOS 런타임은 필요 없다. 시뮬레이터는 개발자 계정이나
배포용 서명 없이 빌드할 수 있다.

```sh
# 이 Mac에 설치한 사용자 로컬 도구를 사용할 때만 실행
source "$HOME/.local/share/violet-ios-tools/env.sh"

rustup target add --toolchain stable aarch64-apple-ios-sim aarch64-apple-ios
npm run ios:init       # 최초 1회: src-tauri/gen/apple 생성 (Git 제외)
npm run build:ios:sim  # Apple Silicon iPhone/iPad 시뮬레이터용 릴리스
```

결과: `src-tauri/gen/apple/build/arm64-sim/Violet.app`.
실기기용 IPA와는 다르며 Mac에서 일반 macOS 앱처럼 열 수 없다.

```sh
xcrun simctl list devices available
# 위 목록에서 원하는 iPad UUID 선택. 이미 부팅했으면 boot 생략.
xcrun simctl boot <IPAD_UUID>
xcrun simctl bootstatus <IPAD_UUID> -b
xcrun simctl install <IPAD_UUID> src-tauri/gen/apple/build/arm64-sim/Violet.app
xcrun simctl launch <IPAD_UUID> dev.violet.app
```

Xcode 27.0 / iOS 27.0 SDK에서 빌드했다. 설정상 최소 iOS 버전은 15.0이며,
낮은 버전 런타임과 실기기는 아직 검증하지 않았다. DB는 시뮬레이터 앱의
별도 샌드박스에 저장되며 Mac 앱의 DB와 자동 공유하지 않는다.

iPad Air 11형(M4) / iOS 27.0 시뮬레이터에서 설치, 프로세스 실행 유지,
사용자 DB 생성과 WebView 리소스 로드를 확인했다. Device Hub UI 자동화가
시간 초과되어 화면 표시와 터치 동작은 아직 검증하지 못했다. 시뮬레이터의
콘텐츠 DB 다운로드/가져오기도 아직 실행하지 않았다.

iOS 빌드를 위해 QuickJS 바인딩을 생성하고 `.cargo/config.toml`에서
Apple Silicon 시뮬레이터의 Clang 타깃 표기를 보정한다. Xcode 27의 Swift
브리지 심벌 연결 문제는 `vendor/swift-rs`의 작은 패치로 해결했다.
`rust-toolchain.toml`의 `llvm-tools`가 이 패치에 필요하다. 패치 이유와
제거 조건은 `vendor/swift-rs/VIOLET-PATCH.md`를 참고한다.

실제 iPhone/iPad 설치는 `aarch64` 타깃으로 별도 빌드하고 Apple 개발 팀과
기기 서명을 구성해야 한다.

## 다른 플랫폼

Tauri 2의 모바일 진입점과 공통 Rust 코드를 사용한다. Windows·Linux·Android는 아직 빌드/실기기 검증하지 않았다. 각 OS의 WebView, 파일 선택, 저장소와 외부 링크 동작을 검증해야 한다.

```sh
npm run tauri -- android init
npm run tauri -- android dev
```

Android는 Android SDK/NDK와 JDK가 필요하다. 데스크톱 패키지는 해당 OS의 툴체인으로 빌드한다. Android 초기화는 아직 실행하지 않았으며 모바일 생성 프로젝트는 Git에서 제외한다.

실제 DB 회귀 검사(임시 디렉터리에 가져온 뒤 자동 제거):

```sh
VIOLET_TEST_ARCHIVE=/path/to/article-db.zip cargo test \
  --manifest-path src-tauri/Cargo.toml --locked import_real_archive -- --ignored --nocapture
```

이번 검증에서는 TypeScript API 테스트 5개, Rust 테스트 5개, 실제 ZIP의 2,954,193건 가져오기와 인덱스 생성, 원격 이미지 URL 메타데이터 해석이 통과했다. macOS 앱에서 직접 Drive 다운로드 → DB 준비 → 검색 결과 표시도 확인했다. 기존 웹 프론트엔드 빌드도 통과했다.
