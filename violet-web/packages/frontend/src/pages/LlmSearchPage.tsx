import { FormEvent, type KeyboardEvent, useEffect, useState } from 'react';
import { useSearchParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { Search } from 'lucide-react';
import { useAppStore } from '../stores/app-store';
import { useLlmSearch } from '../hooks/useLlmSearch';
import { useLlmSearchHistory, useRecordLlmSearchHistory } from '../hooks/useLlmSearchHistory';
import { LlmSearchGrid } from '../components/llm-search/LlmSearchGrid';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import styles from './MessageSearchPage.module.css';

const TOP_K_OPTIONS = [5, 10, 20, 50, 100];
const CANDIDATE_K_OPTIONS = [50, 100, 200, 300, 500, 1000];

function positiveInt(value: string | null, fallback: number): number {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

export function LlmSearchPage() {
  const { t } = useTranslation();
  const [searchParams, setSearchParams] = useSearchParams();
  const queryFromUrl = searchParams.get('q') || '';
  const {
    llmSearchEnabled,
    llmSearchServerUrl,
    llmSearchTopK,
    llmSearchCandidateK,
    llmSearchColumnWidth,
    setLlmSearchTopK,
    setLlmSearchCandidateK,
    setLlmSearchColumnWidth,
  } = useAppStore();
  const topKFromUrl = positiveInt(searchParams.get('topK'), llmSearchTopK);
  const candidateKFromUrl = positiveInt(searchParams.get('candidateK'), llmSearchCandidateK);
  const [inputValue, setInputValue] = useState(queryFromUrl);
  const [selectedTopK, setSelectedTopK] = useState(topKFromUrl);
  const [selectedCandidateK, setSelectedCandidateK] = useState(candidateKFromUrl);
  const [isHistoryOpen, setIsHistoryOpen] = useState(false);
  const [highlightedHistoryIndex, setHighlightedHistoryIndex] = useState(0);
  const { data, isLoading, isError, refetch } = useLlmSearch(
    queryFromUrl,
    topKFromUrl,
    candidateKFromUrl,
    llmSearchServerUrl,
  );
  const { data: historyData } = useLlmSearchHistory(inputValue);
  const recordHistory = useRecordLlmSearchHistory();
  const historyItems = historyData?.items ?? [];

  useEffect(() => setInputValue(queryFromUrl), [queryFromUrl]);
  useEffect(() => {
    setSelectedTopK(topKFromUrl);
    setSelectedCandidateK(candidateKFromUrl);
  }, [topKFromUrl, candidateKFromUrl]);
  useEffect(() => setHighlightedHistoryIndex(0), [historyItems.length, inputValue]);
  useEffect(() => {
    document.title = queryFromUrl
      ? `${queryFromUrl} - ${t('llmSearch.heading')}`
      : `${t('llmSearch.heading')} - Violet`;
    return () => { document.title = 'Violet'; };
  }, [queryFromUrl, t]);

  const executeSearch = (query: string, topK = selectedTopK, candidateK = selectedCandidateK) => {
    const trimmed = query.trim();
    if (!trimmed || candidateK < topK) return;
    setLlmSearchTopK(topK);
    setLlmSearchCandidateK(candidateK);
    recordHistory.mutate({ query: trimmed, topK, candidateK });
    setSearchParams({ q: trimmed, topK: String(topK), candidateK: String(candidateK) });
    setIsHistoryOpen(false);
  };

  const selectHistoryItem = (index: number) => {
    const item = historyItems[index];
    if (!item) return;
    setInputValue(item.query);
    setSelectedTopK(item.topK);
    setSelectedCandidateK(item.candidateK);
    executeSearch(item.query, item.topK, item.candidateK);
  };

  const handleHistoryKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    if (event.nativeEvent.isComposing) return;
    if (!isHistoryOpen) {
      if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        setIsHistoryOpen(true);
        event.preventDefault();
      }
      return;
    }
    if (event.key === 'Escape') {
      setIsHistoryOpen(false);
      event.preventDefault();
    } else if (event.key === 'ArrowDown') {
      setHighlightedHistoryIndex((current) => historyItems.length ? (current + 1) % historyItems.length : 0);
      event.preventDefault();
    } else if (event.key === 'ArrowUp') {
      setHighlightedHistoryIndex((current) => historyItems.length ? (current - 1 + historyItems.length) % historyItems.length : 0);
      event.preventDefault();
    } else if ((event.key === 'Enter' || event.key === 'Tab') && historyItems.length) {
      event.preventDefault();
      selectHistoryItem(highlightedHistoryIndex);
    }
  };

  if (!llmSearchEnabled) {
    return <div className={styles.disabled}>{t('llmSearch.disabled')}</div>;
  }

  return (
    <div className={styles.page}>
      <div className={styles.toolbar}>
        <form className={styles.searchForm} onSubmit={(event: FormEvent) => {
          event.preventDefault();
          executeSearch(inputValue);
        }}>
          <div className={styles.searchRow}>
            <div className={styles.inputWrapper}>
              <Search size={18} className={styles.searchIcon} />
              <input
                className={styles.searchInput}
                value={inputValue}
                onChange={(event) => {
                  setInputValue(event.target.value);
                  setIsHistoryOpen(true);
                }}
                onFocus={() => setIsHistoryOpen(true)}
                onBlur={() => window.setTimeout(() => setIsHistoryOpen(false), 120)}
                onKeyDown={handleHistoryKeyDown}
                placeholder={t('llmSearch.placeholder')}
              />
              {isHistoryOpen && historyItems.length > 0 && (
                <div className={styles.historyDropdown}>
                  <div className={styles.historyHeader}>{t('llmSearch.searchHistory')}</div>
                  {historyItems.map((item, index) => (
                    <button
                      key={item.query}
                      type="button"
                      className={`${styles.historyItem} ${index === highlightedHistoryIndex ? styles.highlighted : ''}`}
                      onMouseDown={(event) => event.preventDefault()}
                      onMouseEnter={() => setHighlightedHistoryIndex(index)}
                      onClick={() => selectHistoryItem(index)}
                    >
                      <span className={styles.historyQuery}>{item.query}</span>
                      <span className={styles.historyCount}>
                        k{item.topK}/{item.candidateK} · {t('llmSearch.historyCount', { count: item.searchCount })}
                      </span>
                    </button>
                  ))}
                </div>
              )}
            </div>

            <select
              className={styles.resultLimitSelect}
              value={selectedTopK}
              onChange={(event) => {
                const value = Number(event.target.value);
                setSelectedTopK(value);
                if (selectedCandidateK < value) setSelectedCandidateK(value);
              }}
              aria-label={t('llmSearch.topK')}
              title={t('llmSearch.topK')}
            >
              {TOP_K_OPTIONS.map((value) => <option key={value} value={value}>top {value}</option>)}
            </select>
            <select
              className={styles.resultLimitSelect}
              value={selectedCandidateK}
              onChange={(event) => setSelectedCandidateK(Number(event.target.value))}
              aria-label={t('llmSearch.candidateK')}
              title={t('llmSearch.candidateK')}
            >
              {CANDIDATE_K_OPTIONS.filter((value) => value >= selectedTopK).map((value) => (
                <option key={value} value={value}>candidate {value}</option>
              ))}
            </select>
            <button className={styles.searchBtn} type="submit">{t('llmSearch.search')}</button>
            <input
              type="range"
              className={styles.columnSlider}
              min={180}
              max={900}
              step={10}
              value={llmSearchColumnWidth}
              onChange={(event) => setLlmSearchColumnWidth(Number(event.target.value))}
              aria-label={t('llmSearch.columnWidth')}
            />
          </div>
        </form>
        {data && (
          <div className={styles.resultCount}>
            {t('llmSearch.resultSummary', { count: data.total, seconds: (data.elapsedMs / 1000).toFixed(2) })}
          </div>
        )}
      </div>

      {isLoading && <LoadingSpinner />}
      {isError && (
        <div className={styles.error}>
          <span>{t('llmSearch.error')}</span>
          <button type="button" className={styles.retryBtn} onClick={() => refetch()}>{t('llmSearch.retry')}</button>
        </div>
      )}
      {!isLoading && data?.results.length === 0 && <div className={styles.empty}>{t('llmSearch.empty')}</div>}
      {!isLoading && data && data.results.length > 0 && (
        <LlmSearchGrid results={data.results} columnWidth={llmSearchColumnWidth} />
      )}
    </div>
  );
}
