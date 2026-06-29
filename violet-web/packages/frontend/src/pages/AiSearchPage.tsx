import { useState, FormEvent, useEffect } from 'react';
import { useSearchParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useAiSearch } from '../hooks/useAiSearch';
import { AiAnswerCard } from '../components/ai-search/AiAnswerCard';
import { AiSearchResultGrid } from '../components/ai-search/AiSearchResultGrid';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import styles from './AiSearchPage.module.css';

export function AiSearchPage() {
  const { t } = useTranslation();
  const [searchParams, setSearchParams] = useSearchParams();
  const queryFromUrl = searchParams.get('q') || '';
  const topKFromUrl = parseInt(searchParams.get('top_k') || '5') || 5;
  const modeFromUrl = searchParams.get('mode') || 'super_fast';
  const [inputValue, setInputValue] = useState(queryFromUrl);
  const [topK, setTopK] = useState(topKFromUrl);
  const [mode, setMode] = useState(modeFromUrl);

  const { response, articles, isLoading, isError } = useAiSearch(queryFromUrl, topKFromUrl, modeFromUrl);

  useEffect(() => {
    setInputValue(queryFromUrl);
  }, [queryFromUrl]);

  useEffect(() => {
    setTopK(topKFromUrl);
  }, [topKFromUrl]);

  useEffect(() => {
    setMode(modeFromUrl);
  }, [modeFromUrl]);

  useEffect(() => {
    document.title = queryFromUrl ? `AI: ${queryFromUrl} - Violet` : 'AI Search - Violet';
    return () => { document.title = 'Violet'; };
  }, [queryFromUrl]);

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    const q = inputValue.trim();
    if (!q) return;
    const params: Record<string, string> = { q };
    if (topK !== 5) params.top_k = String(topK);
    if (mode !== 'fast') params.mode = mode;
    setSearchParams(params);
  };

  return (
    <div className={styles.page}>
      <h1 className={styles.heading}>{t('aiSearch.heading')}</h1>

      <form className={styles.searchForm} onSubmit={handleSubmit}>
        <div className={styles.searchRow}>
          <input
            className={styles.searchInput}
            type="text"
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            placeholder={t('aiSearch.placeholder')}
          />
          <label className={styles.optionLabel}>
            {t('aiSearch.mode')}
            <select
              className={styles.optionSelect}
              value={mode}
              onChange={(e) => setMode(e.target.value)}
            >
              <option value="super_fast">{t('aiSearch.modeSuperFast')}</option>
              <option value="fast">{t('aiSearch.modeFast')}</option>
              <option value="detail">{t('aiSearch.modeDetail')}</option>
            </select>
          </label>
          <label className={styles.optionLabel}>
            Top K
            <select
              className={styles.optionSelect}
              value={topK}
              onChange={(e) => setTopK(Number(e.target.value))}
            >
              {[3, 5, 10, 15, 20].map((n) => (
                <option key={n} value={n}>{n}</option>
              ))}
            </select>
          </label>
        </div>
      </form>

      {isLoading && <LoadingSpinner />}

      {isError && (
        <div className={styles.error}>{t('aiSearch.error')}</div>
      )}

      {response && !isLoading && (
        <>
          {response.answer && <AiAnswerCard answer={response.answer} />}
          <AiSearchResultGrid articles={articles} results={response.results} />
        </>
      )}
    </div>
  );
}
