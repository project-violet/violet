# Violet 개발자 문서

이 문서는 `Violet` 앱 구동에 필요한 모든 기능들 및 앱 기능에 관한 구현을 설명합니다.

## 1. 데이터베이스

### 1.1. 데이터베이스 동기화

데이터베이스 동기화는 서버에서 `hsync` 프로그램으로 진행됩니다.
`hsync` 프로젝트는 https://github.com/project-violet/violet-server/tree/master/tools/hsync 여기를 참고하세요.

모든 데이터베이스는 https://github.com/violet-dev/db/releases 여기에 업로드됩니다.

### 1.2. 7z을 사용하는 이유

데이터베이스 파일 및 인덱싱 파일은 중복된 항목들이 굉장히 많습니다.
단순하게 파일압축만 하는 것에 비해 1/6배 이상 크기를 줄일 수 있습니다.
7z를 사용한 이유는 압축률이 굉장히 좋으며 안드로이드에서 `p7zip`를 사용해 매우 빠르게 압축을 풀 수 있기 때문입니다.

### 1.3. 데이터베이스 구성요소

데이터베이스 압축파일은 다음과 같은 파일로 구성되어있습니다.

```
1. data.db
2. index.json
3. tag-artist.json
4. tag-group.json
5. tag-index.json
6. tag-uploader.json
```

`data.db`는 쿼리를 위한 SQLite기반의 데이터베이스입니다. 
이 데이터베이스는 모든 작품들의 데이터가 포함되어있습니다.

`index.json`은 `tag` 및 `lang`, `artist`, `group`, `type`, `uploader`, `series`, `character`, `class` 토큰들에 대한 태그 정보와 태그의 총 개수가 포함되어있는 파일입니다.

`tag-index.json`은 `tag-artist.json`와 `tag-group.json`, `tag-uploader.json`에서 사용할 인덱스 정보가 들어있습니다. `artist`와 `group`, `uploader` 태그들이 각각 하나의 고유 인덱스 번호를 가지고 있으며, 이 고유 인덱스 번호는 해당 태그와 동치입니다.

`tag-artist.json`와 `tag-group.json`, `tag-uploader.json`은 각 `artist`와 `group`, `uploader`가 가진 작품들의 모든 태그목록이 합산되어 포함된 파일입니다.
이 파일들은 빠른 비슷한 작가/그룹/업로더 기능을 제공하기 위해 사용됩니다.

## 2. 검색

기초적인 검색방식은 메뉴얼에 서술되어있으니 메뉴얼을 먼저 확인한 후 읽어주세요.

웹 검색과 데이터베이스는 사용자 설정에 따라 달라질 수 있습니다.
따라서 사용자의 우선순위에 따라 다른 검색 방식을 제공하기 위해 다음과 같은 함수를 구현했습니다.

https://github.com/project-violet/violet/blob/d158779a99ba23b9621a3c44243a774a1e0cfb10/lib/component/hentai.dart#L35

이 함수는 웹 검색 사용 유무를 확인하고 웹 검색 시 우선순위를 참조해 차례대로 검색합니다.

데이터베이스 검색은 다음과 같이 진행됩니다.

1. 사용자가 검색창에서 검색버튼을 누르면
2. 검색 문장이 SQLite용 쿼리 문장으로 변환됩니다.
  참고: https://github.com/project-violet/violet/blob/d158779a99ba23b9621a3c44243a774a1e0cfb10/lib/component/hitomi/hitomi.dart#L322
3. LIMIT와 OFFSET을 이용해 필요한 만큼 데이터를 불러옵니다.
  참고: https://github.com/project-violet/violet/blob/d158779a99ba23b9621a3c44243a774a1e0cfb10/lib/pages/search/search_page.dart#L395

## 3. 비슷한 작가/그룹/업로더 기능

이 기능은 `Cosine Distance`를 이용해 구현되었습니다.

참고: https://github.com/project-violet/violet/blob/d158779a99ba23b9621a3c44243a774a1e0cfb10/lib/component/hitomi/indexs.dart#L37

## 4. 다국어 지원

`Violet`은 가능한 모든 언어와 알파벳을 지원하기 위해 `IETF language tag`를 사용합니다.

## 5. 설정

모든 설정 정보는 https://github.com/project-violet/violet/blob/d158779a99ba23b9621a3c44243a774a1e0cfb10/lib/settings/settings.dart 여기에 저장됩니다.