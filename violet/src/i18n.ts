import i18n from '../../violet-web/packages/frontend/src/i18n/config';

const resources = {
  en: {
    extracting: 'Extracting database…', validating: 'Checking database…', indexing: 'Creating search indexes. This can take several minutes…',
    source: 'Downloads article-db.zip from the shared Google Drive (July 5, 2026, about 866 MB). Includes all languages. You can also import a ZIP or SQLite file. Allow several GB of free space for extraction and search indexes.',
    title: 'Violet on this device', description: 'Search, bookmarks, reading history and downloads are stored on this device. Choose a content database to get started.',
    language: 'Database language', global: 'All languages', ko: 'Korean', en: 'English', ja: 'Japanese', zh: 'Chinese',
    download: 'Download database', import: 'Import existing database', working: 'Preparing database…', ready: 'Open Violet',
    retry: 'Retry', error: 'Could not prepare the database.', startupError: 'Could not start the local app.',
    note: 'This first native build includes search, the reader, bookmarks, history and downloads. Server-dependent AI and analysis pages will be added separately.',
    privacy: 'Your existing web database is kept separate. Importing copies content without modifying the original.',
  },
  ko: {
    extracting: 'DB 압축 해제 중…', validating: 'DB 무결성 확인 중…', indexing: '검색 인덱스 생성 중입니다. 몇 분 정도 걸릴 수 있습니다…',
    source: '공유 Google Drive의 article-db.zip을 받습니다(2026-07-05, 약 866MB). 모든 언어가 포함되며 ZIP·SQLite 파일을 직접 가져올 수도 있습니다. 압축 해제와 검색 인덱스 생성을 위해 수 GB의 여유 공간이 필요합니다.',
    title: '이 기기의 Violet', description: '검색 DB, 북마크, 읽기 기록과 다운로드를 이 기기에 저장합니다. 사용할 콘텐츠 DB를 선택하세요.',
    language: 'DB 언어', global: '모든 언어', ko: '한국어', en: '영어', ja: '일본어', zh: '중국어',
    download: 'DB 다운로드', import: '기존 DB 가져오기', working: 'DB 준비 중…', ready: 'Violet 열기',
    retry: '다시 시도', error: 'DB를 준비하지 못했습니다.', startupError: '로컬 앱을 시작하지 못했습니다.',
    note: '이번 네이티브 빌드는 검색, 뷰어, 북마크, 읽기 기록, 다운로드를 지원합니다. 별도 서버가 필요한 AI·분석 화면은 이후 연결됩니다.',
    privacy: '기존 웹의 DB와 별도로 저장합니다. 가져오기는 콘텐츠를 복사하며 원본을 변경하지 않습니다.',
  },
  ja: {
    extracting: 'DBを展開中…', validating: 'DBを検証中…', indexing: '検索インデックスを作成中です。数分かかる場合があります…',
    source: '共有Google Driveからarticle-db.zipを取得します（2026-07-05、約866MB）。全言語を含みます。ZIP・SQLiteファイルの読み込みも可能です。展開と検索インデックス用に数GBの空き容量が必要です。',
    title: 'この端末の Violet', description: '検索DB、ブックマーク、履歴とダウンロードをこの端末に保存します。コンテンツDBを選択してください。',
    language: 'DBの言語', global: 'すべての言語', ko: '韓国語', en: '英語', ja: '日本語', zh: '中国語',
    download: 'DBをダウンロード', import: '既存のDBを読み込む', working: 'DBを準備中…', ready: 'Violetを開く',
    retry: '再試行', error: 'DBを準備できませんでした。', startupError: 'ローカルアプリを起動できませんでした。',
    note: '初期ネイティブ版は検索、ビューアー、ブックマーク、履歴、ダウンロードに対応します。サーバーを必要とするAI・分析画面は後日対応します。',
    privacy: '既存のWeb版DBとは別に保存します。読み込みはコピーを作成し、元のDBを変更しません。',
  },
  zh: {
    extracting: '正在解压数据库…', validating: '正在检查数据库…', indexing: '正在创建搜索索引，可能需要几分钟…',
    source: '从共享Google Drive下载article-db.zip（2026-07-05，约866MB），包含所有语言。也可导入ZIP或SQLite文件。解压和创建搜索索引需要数GB可用空间。',
    title: '此设备上的 Violet', description: '搜索数据库、书签、阅读记录和下载保存在此设备上。请选择内容数据库。',
    language: '数据库语言', global: '所有语言', ko: '韩语', en: '英语', ja: '日语', zh: '中文',
    download: '下载数据库', import: '导入现有数据库', working: '正在准备数据库…', ready: '打开 Violet',
    retry: '重试', error: '无法准备数据库。', startupError: '无法启动本地应用。',
    note: '首个原生版本支持搜索、阅读器、书签、历史记录和下载。需要服务器的AI和分析页面将在以后添加。',
    privacy: '与现有网页版数据库分开保存。导入会复制内容，不会修改原始文件。',
  },
};

for (const [language, values] of Object.entries(resources)) i18n.addResourceBundle(language, 'native', values);
export const t = (key: keyof typeof resources.en) => i18n.t(key, { ns: 'native' });
