import { FormEvent, useEffect, useRef, useState } from 'react';
import { useSearchParams } from 'react-router';
import { Loader2, Search } from 'lucide-react';
import { useAppStore } from '../stores/app-store';
import { fetchWorkExperiment, type WorkExperimentResponse } from '../api/work-experiment';
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
  const workIdFromUrl = searchParams.get('work') || '';
  const messageQueryFromUrl = searchParams.get('q') || '';
  const [workId, setWorkId] = useState(workIdFromUrl);
  const [messageQuery, setMessageQuery] = useState(messageQueryFromUrl);
  const [result, setResult] = useState<WorkExperimentResponse | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const requestSeq = useRef(0);

  const runExperiment = async (workIdValue: string, queryValue: string) => {
    const trimmedWorkId = workIdValue.trim();
    if (!trimmedWorkId) {
      setError('작품 번호를 입력해 주세요.');
      return;
    }

    setLoading(true);
    setError('');
    const seq = requestSeq.current + 1;
    requestSeq.current = seq;
    try {
      const response = await fetchWorkExperiment({
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
    setWorkId(workIdFromUrl);
    setMessageQuery(messageQueryFromUrl);
    if (workIdFromUrl.trim()) {
      void runExperiment(workIdFromUrl, messageQueryFromUrl);
    }
  }, [workIdFromUrl, messageQueryFromUrl]);

  const setExperimentParams = (workIdValue: string, queryValue: string) => {
    const trimmedWorkId = workIdValue.trim();
    const trimmedQuery = queryValue.trim();
    const params: Record<string, string> = {};
    if (trimmedWorkId) params.work = trimmedWorkId;
    if (trimmedQuery) params.q = trimmedQuery;
    setSearchParams(params);
  };

  const handleSubmit = (event: FormEvent) => {
    event.preventDefault();
    if (!workId.trim()) {
      setError('작품 번호를 입력해 주세요.');
      return;
    }
    setExperimentParams(workId, messageQuery);
  };

  const handleKeywordSearch = (keyword: string) => {
    const currentWorkId = result?.work.article_id || workId;
    setWorkId(currentWorkId);
    setMessageQuery(keyword);
    setExperimentParams(currentWorkId, keyword);
  };

  return (
    <div className={styles.page}>
      <form className={styles.toolbar} onSubmit={handleSubmit}>
        <div className={styles.inputGroup}>
          <label htmlFor="work-experiment-id">작품 번호</label>
          <input
            id="work-experiment-id"
            type="text"
            inputMode="numeric"
            value={workId}
            onChange={(event) => setWorkId(event.target.value)}
            placeholder="123456"
          />
        </div>

        <div className={styles.inputGroup}>
          <label htmlFor="work-experiment-query">작품 내 message 검색어</label>
          <input
            id="work-experiment-query"
            type="text"
            value={messageQuery}
            onChange={(event) => setMessageQuery(event.target.value)}
            placeholder="검색어"
          />
        </div>

        <button type="submit" className={styles.searchButton} disabled={loading || !workId.trim()}>
          {loading ? <Loader2 size={18} className={styles.spinIcon} /> : <Search size={18} />}
          {loading ? '불러오는 중' : '조회'}
        </button>
      </form>

      {error && <div className={styles.error}>{error}</div>}

      {result && (
        <div className={styles.content}>
          <section className={styles.panel}>
            <div className={styles.panelHeader}>
              <h2>대표 키워드</h2>
              <span>{result.work.article_id} / {result.work.top_keywords.length.toLocaleString()}개</span>
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
              <div className={styles.empty}>검색어를 넣으면 해당 작품 안에서만 message를 찾습니다.</div>
            )}
          </section>
        </div>
      )}
    </div>
  );
}
