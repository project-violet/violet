import { FormEvent, useEffect, useRef, useState } from 'react';
import { useSearchParams } from 'react-router';
import { Loader2, Search } from 'lucide-react';
import { useAppStore } from '../stores/app-store';
import {
  fetchAuthorExperiment,
  fetchWorkExperiment,
  type WorkExperimentMode,
  type WorkExperimentResponse,
} from '../api/work-experiment';
import { MessageSearchCard } from '../components/message-search/MessageSearchCard';
import styles from './WorkExperimentPage.module.css';

function formatStat(value: number): string {
  return value > 0 ? value.toLocaleString() : '통계 없음';
}

function distributeToColumns<T>(items: T[], columnCount: number): T[][] {
  const columns: T[][] = Array.from({ length: columnCount }, () => []);
  items.forEach((item, index) => {
    columns[index % columnCount].push(item);
  });
  return columns;
}

export function WorkExperimentPage() {
  const [searchParams, setSearchParams] = useSearchParams();
  const {
    keywordGraphServerUrl,
    messageSearchServerUrl,
    messageSearchResultLimit,
  } = useAppStore();
  const modeFromUrl: WorkExperimentMode = searchParams.get('mode') === 'author' ? 'author' : 'work';
  const workIdFromUrl = searchParams.get('work') || '';
  const authorFromUrl = searchParams.get('author') || '';
  const messageQueryFromUrl = searchParams.get('q') || '';
  const [mode, setMode] = useState<WorkExperimentMode>(modeFromUrl);
  const [workId, setWorkId] = useState(workIdFromUrl);
  const [author, setAuthor] = useState(authorFromUrl);
  const [messageQuery, setMessageQuery] = useState(messageQueryFromUrl);
  const [result, setResult] = useState<WorkExperimentResponse | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const requestSeq = useRef(0);

  const runExperiment = async (
    modeValue: WorkExperimentMode,
    workIdValue: string,
    authorValue: string,
    queryValue: string,
  ) => {
    const trimmedWorkId = workIdValue.trim();
    const trimmedAuthor = authorValue.trim();
    if (modeValue === 'work' && !trimmedWorkId) {
      setError('작품 번호를 입력해 주세요.');
      return;
    }
    if (modeValue === 'author' && !trimmedAuthor) {
      setError('작가를 입력해 주세요.');
      return;
    }

    setLoading(true);
    setError('');
    const seq = requestSeq.current + 1;
    requestSeq.current = seq;
    try {
      const response = modeValue === 'author'
        ? await fetchAuthorExperiment({
            author: trimmedAuthor,
            messageQuery: queryValue,
            keywordGraphServerUrl,
            messageSearchServerUrl,
            limit: messageSearchResultLimit,
          })
        : await fetchWorkExperiment({
            workId: trimmedWorkId,
            messageQuery: queryValue,
            keywordGraphServerUrl,
            messageSearchServerUrl,
            limit: messageSearchResultLimit,
          });
      if (requestSeq.current !== seq) return;
      setResult(response);
    } catch (err) {
      if (requestSeq.current !== seq) return;
      setResult(null);
      setError(err instanceof Error ? err.message : '실험 데이터를 불러오지 못했습니다.');
    } finally {
      if (requestSeq.current === seq) {
        setLoading(false);
      }
    }
  };

  useEffect(() => {
    setMode(modeFromUrl);
    setWorkId(workIdFromUrl);
    setAuthor(authorFromUrl);
    setMessageQuery(messageQueryFromUrl);
    if (modeFromUrl === 'author' && authorFromUrl.trim()) {
      void runExperiment('author', workIdFromUrl, authorFromUrl, messageQueryFromUrl);
    } else if (modeFromUrl === 'work' && workIdFromUrl.trim()) {
      void runExperiment('work', workIdFromUrl, authorFromUrl, messageQueryFromUrl);
    }
  }, [modeFromUrl, workIdFromUrl, authorFromUrl, messageQueryFromUrl]);

  const setExperimentParams = (
    modeValue: WorkExperimentMode,
    workIdValue: string,
    authorValue: string,
    queryValue: string,
  ) => {
    const trimmedWorkId = workIdValue.trim();
    const trimmedAuthor = authorValue.trim();
    const trimmedQuery = queryValue.trim();
    const params: Record<string, string> = {};
    params.mode = modeValue;
    if (modeValue === 'author') {
      if (trimmedAuthor) params.author = trimmedAuthor;
    } else if (trimmedWorkId) {
      params.work = trimmedWorkId;
    }
    if (trimmedQuery) params.q = trimmedQuery;
    setSearchParams(params);
  };

  const handleSubmit = (event: FormEvent) => {
    event.preventDefault();
    if (mode === 'work' && !workId.trim()) {
      setError('작품 번호를 입력해 주세요.');
      return;
    }
    if (mode === 'author' && !author.trim()) {
      setError('작가를 입력해 주세요.');
      return;
    }
    setExperimentParams(mode, workId, author, messageQuery);
  };

  const handleKeywordSearch = (keyword: string) => {
    setMessageQuery(keyword);
    if (result?.scope === 'author') {
      const currentAuthor = result.author || author;
      setAuthor(currentAuthor);
      setExperimentParams('author', workId, currentAuthor, keyword);
      return;
    }
    const currentWorkId = result?.work.article_id || workId;
    setWorkId(currentWorkId);
    setExperimentParams('work', currentWorkId, author, keyword);
  };

  const handleModeChange = (nextMode: WorkExperimentMode) => {
    setMode(nextMode);
    setResult(null);
    setError('');
  };

  const identifierValue = mode === 'author' ? author : workId;
  const canSubmit = Boolean(identifierValue.trim()) && !loading;
  const resultScopeText = result?.scope === 'author'
    ? `${result.author || author} / ${(result.work.work_count ?? result.articleIds.length).toLocaleString()}작품 / ${result.work.top_keywords.length.toLocaleString()}개`
    : `${result?.work.article_id ?? ''} / ${result?.work.top_keywords.length.toLocaleString() ?? '0'}개`;
  const messageEmptyText = result?.scope === 'author'
    ? '검색어를 넣으면 해당 작가 작품 안에서만 message를 찾습니다.'
    : '검색어를 넣으면 해당 작품 안에서만 message를 찾습니다.';

  return (
    <div className={styles.page}>
      <form className={styles.toolbar} onSubmit={handleSubmit}>
        <div className={styles.modeControl} role="group" aria-label="실험 범위">
          <button
            type="button"
            className={mode === 'work' ? styles.modeActive : ''}
            onClick={() => handleModeChange('work')}
          >
            작품
          </button>
          <button
            type="button"
            className={mode === 'author' ? styles.modeActive : ''}
            onClick={() => handleModeChange('author')}
          >
            작가
          </button>
        </div>

        <div className={styles.inputGroup}>
          <label htmlFor="work-experiment-id">{mode === 'author' ? '작가' : '작품 번호'}</label>
          <input
            id="work-experiment-id"
            type="text"
            inputMode={mode === 'work' ? 'numeric' : 'text'}
            value={mode === 'author' ? author : workId}
            onChange={(event) => {
              if (mode === 'author') {
                setAuthor(event.target.value);
              } else {
                setWorkId(event.target.value);
              }
            }}
            placeholder={mode === 'author' ? '작가명' : '123456'}
          />
        </div>

        <div className={styles.inputGroup}>
          <label htmlFor="work-experiment-query">
            {mode === 'author' ? '작가 내 message 검색어' : '작품 내 message 검색어'}
          </label>
          <input
            id="work-experiment-query"
            type="text"
            value={messageQuery}
            onChange={(event) => setMessageQuery(event.target.value)}
            placeholder="검색어"
          />
        </div>

        <button type="submit" className={styles.searchButton} disabled={!canSubmit}>
          {loading ? <Loader2 size={18} className={styles.spinIcon} /> : <Search size={18} />}
          {loading ? '불러오는 중' : '조회'}
        </button>
      </form>

      {error && <div className={styles.error}>{error}</div>}

      {result && (
        <div className={styles.content}>
          <section className={`${styles.panel} ${styles.keywordPanel}`}>
            <div className={styles.panelHeader}>
              <h2>대표 키워드</h2>
              <span>{resultScopeText}</span>
            </div>
            <div className={styles.stats}>
              <span>페이지 {formatStat(result.work.total_pages)}</span>
              <span>대사 {formatStat(result.work.dialogue_count)}</span>
              <span>글자 {formatStat(result.work.char_count)}</span>
            </div>
            <div className={styles.keywordList}>
              {result.work.top_keywords.length > 0 ? (
                result.work.top_keywords.map((keyword) => (
                  <button
                    key={keyword.keyword}
                    type="button"
                    className={styles.keywordItem}
                    onClick={() => handleKeywordSearch(keyword.keyword)}
                    disabled={loading}
                    title={`${keyword.keyword} 메시지 검색`}
                  >
                    <span className={styles.keywordRank}>#{keyword.rank}</span>
                    <span className={styles.keywordName}>{keyword.keyword}</span>
                    <span className={styles.keywordMeta}>
                      co {keyword.cooccur ?? 0} / df {keyword.df} / score {keyword.score.toFixed(1)} / tf {keyword.tf}
                    </span>
                  </button>
                ))
              ) : (
                <div className={styles.empty}>키워드 없음</div>
              )}
            </div>
          </section>

          <section className={styles.panel}>
            <div className={styles.panelHeader}>
              <h2>Message 검색</h2>
              <span>{result.messages ? `${result.messages.total.toLocaleString()}개` : '검색어 없음'}</span>
            </div>
            {result.messages ? (
              <div className={styles.messageList}>
                {result.messages.results.length > 0 ? (
                  distributeToColumns(result.messages.results, 3).map((column, columnIndex) => (
                    <div key={columnIndex} className={styles.messageColumn}>
                      {column.map((message, index) => (
                        <MessageSearchCard
                          key={`${message.articleId}-${message.page}-${index}`}
                          result={message}
                        />
                      ))}
                    </div>
                  ))
                ) : (
                  <div className={styles.empty}>검색 결과 없음</div>
                )}
              </div>
            ) : (
              <div className={styles.empty}>{messageEmptyText}</div>
            )}
          </section>
        </div>
      )}
    </div>
  );
}
