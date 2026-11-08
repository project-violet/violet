import { FormEvent, type KeyboardEvent, type ReactNode, useId, useCallback, useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { MessageSearchMode, MessageSearchFilters } from '@violet-web/shared';
import { ArrowUp, Search } from 'lucide-react';
import { useAppStore } from '../../stores/app-store';
import { useMessageSearch } from '../../hooks/useMessageSearch';
import { useMessageSearchHistory, useRecordMessageSearchHistory } from '../../hooks/useMessageSearchHistory';
import { MessageArticleConditions } from './MessageArticleConditions';
import { MessageSearchGrid } from './MessageSearchGrid';
import { LoadingSpinner } from '../common/LoadingSpinner';
import styles from '../../pages/MessageSearchPage.module.css';

const MODES: MessageSearchMode[] = ['contains', 'similar', 'lcs'];
const RESULT_LIMITS = [25, 50, 100, 200, 500];
const FILTER_ERRORS: Record<string, string> = {
  INVALID_ARTICLE_QUERY: 'messageSearch.invalidConditions',
  UNSUPPORTED_FILTER_MODE: 'messageSearch.conditionsModeError',
  FILTER_UNSUPPORTED: 'messageSearch.conditionsBackendRequired',
};

interface MessageSearchPanelProps {
  query: string;
  mode: MessageSearchMode;
  onSearch: (query: string, mode: MessageSearchMode, articleQuery?: string) => void;
  filters?: MessageSearchFilters;
  articleIds?: number[];
  dateRange?: ReactNode;
  showArticleConditions?: boolean;
}

export function MessageSearchPanel({ query: queryFromUrl, mode, onSearch, filters = {}, articleIds, dateRange, showArticleConditions = false }: MessageSearchPanelProps) {
  const { t } = useTranslation();
  const pageRef = useRef<HTMLDivElement>(null);
  const historyId = useId();
  const {
    messageSearchEnabled,
    messageSearchServerUrl,
    messageSearchResultLimit,
    messageSearchColumnWidth,
    setMessageSearchResultLimit,
    setMessageSearchColumnWidth,
  } = useAppStore();

  const [inputValue, setInputValue] = useState(queryFromUrl);
  const [articleInput, setArticleInput] = useState(filters.articleQuery || '');
  const [selectedMode, setSelectedMode] = useState<MessageSearchMode>(mode);
  const [isHistoryOpen, setIsHistoryOpen] = useState(false);
  const [highlightedHistoryIndex, setHighlightedHistoryIndex] = useState(0);
  const [showScrollTop, setShowScrollTop] = useState(false);

  const { data, isLoading, isError, error, refetch } = useMessageSearch(
    queryFromUrl,
    mode,
    messageSearchResultLimit,
    messageSearchServerUrl,
    filters,
    articleIds,
    messageSearchEnabled,
  );
  const searchError = error as { response?: { data?: { code?: string } }; code?: string } | null;
  const errorCode = searchError?.response?.data?.code || searchError?.code || '';
  const { data: historyData } = useMessageSearchHistory(inputValue);
  const recordHistory = useRecordMessageSearchHistory();
  const historyItems = historyData?.items ?? [];

  useEffect(() => {
    setInputValue(queryFromUrl);
  }, [queryFromUrl]);


  useEffect(() => {
    setSelectedMode(mode);
  }, [mode]);

  useEffect(() => {
    setHighlightedHistoryIndex(0);
  }, [historyItems.length, inputValue]);

  const getScrollContainer = useCallback(() => {
    return pageRef.current?.closest<HTMLElement>('[data-message-search-scroll], main') ?? null;
  }, []);

  useEffect(() => {
    const scrollContainer = getScrollContainer();
    if (!scrollContainer) return;

    const handleScroll = () => {
      setShowScrollTop(scrollContainer.scrollTop > 320);
    };

    handleScroll();
    scrollContainer.addEventListener('scroll', handleScroll, { passive: true });
    return () => scrollContainer.removeEventListener('scroll', handleScroll);
  }, [getScrollContainer]);

  useEffect(() => { setArticleInput(filters.articleQuery || ''); }, [filters.articleQuery]);

  const executeSearch = (query: string) => {
    const q = query.trim();
    if (!q) return;

    if (articleIds?.length === 0) return;
    recordHistory.mutate(q);
    const conditions = showArticleConditions ? articleInput.trim() : undefined;
    const nextMode = conditions && selectedMode === 'lcs' ? 'contains' : selectedMode;
    if (q === queryFromUrl && nextMode === mode && (conditions || '') === (filters.articleQuery?.trim() || '')) {
      void refetch();
    }
    onSearch(q, nextMode, conditions);
    setIsHistoryOpen(false);
  };

  const handleSubmit = (event: FormEvent) => {
    event.preventDefault();
    executeSearch(inputValue);
  };

  const handleScrollToTop = () => {
    getScrollContainer()?.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const selectHistoryItem = (index: number) => {
    const item = historyItems[index];
    if (!item) return;
    setInputValue(item.query);
    executeSearch(item.query);
  };

  const handleHistoryKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    if (event.nativeEvent.isComposing) return;

    if (!isHistoryOpen) {
      if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        setIsHistoryOpen(true);
        setHighlightedHistoryIndex(0);
        event.preventDefault();
      }
      return;
    }

    switch (event.key) {
      case 'Escape':
        setIsHistoryOpen(false);
        event.preventDefault();
        break;
      case 'ArrowDown':
        setHighlightedHistoryIndex((current) =>
          historyItems.length > 0 ? (current + 1) % historyItems.length : 0,
        );
        event.preventDefault();
        break;
      case 'ArrowUp':
        setHighlightedHistoryIndex((current) =>
          historyItems.length > 0
            ? (current - 1 + historyItems.length) % historyItems.length
            : 0,
        );
        event.preventDefault();
        break;
      case 'Enter':
      case 'Tab':
        if (historyItems.length > 0) {
          event.preventDefault();
          selectHistoryItem(highlightedHistoryIndex);
        }
        break;
    }
  };

  if (!messageSearchEnabled) {
    return (
      <div className={styles.page} ref={pageRef}>
        <div className={styles.disabled}>{t('messageSearch.disabled')}</div>
      </div>
    );
  }

  return (
    <div className={styles.page} ref={pageRef}>
      <div className={styles.toolbar}>
        <form className={styles.searchForm} onSubmit={handleSubmit}>
          <div className={styles.searchRow}>
            <div className={styles.inputWrapper}>
              <Search size={18} className={styles.searchIcon} />
              <input
                className={styles.searchInput}
                type="text"
                value={inputValue}
                onChange={(event) => {
                  setInputValue(event.target.value);
                  setIsHistoryOpen(true);
                }}
                onFocus={() => setIsHistoryOpen(true)}
                onBlur={() => window.setTimeout(() => setIsHistoryOpen(false), 120)}
                onKeyDown={handleHistoryKeyDown}
                placeholder={t('messageSearch.placeholder')}
                role="combobox"
                aria-expanded={isHistoryOpen && historyItems.length > 0}
                aria-autocomplete="list"
                aria-controls={historyId}
                aria-activedescendant={
                  isHistoryOpen && historyItems.length > 0
                    ? `${historyId}-${highlightedHistoryIndex}`
                    : undefined
                }
              />
              {isHistoryOpen && historyItems.length > 0 && (
                <div
                  id={historyId}
                  className={styles.historyDropdown}
                  role="listbox"
                >
                  <div className={styles.historyHeader}>
                    {t('messageSearch.searchHistory')}
                  </div>
                  {historyItems.map((item, index) => (
                    <button
                      key={item.query}
                      id={`${historyId}-${index}`}
                      type="button"
                      className={`${styles.historyItem} ${
                        index === highlightedHistoryIndex ? styles.highlighted : ''
                      }`}
                      onMouseDown={(event) => event.preventDefault()}
                      onMouseEnter={() => setHighlightedHistoryIndex(index)}
                      onClick={() => selectHistoryItem(index)}
                      role="option"
                      aria-selected={index === highlightedHistoryIndex}
                    >
                      <span className={styles.historyQuery}>{item.query}</span>
                      <span className={styles.historyCount}>
                        {t('messageSearch.historyCount', { count: item.searchCount })}
                      </span>
                    </button>
                  ))}
                </div>
              )}
            </div>

            {showArticleConditions && <MessageArticleConditions value={articleInput} onChange={(value) => {
              setArticleInput(value);
              if (value.trim() && selectedMode === 'lcs') setSelectedMode('contains');
            }} />}

            {dateRange}

            <div className={styles.segmented}>
              {MODES.filter((item) => (articleIds === undefined && !articleInput.trim()) || item !== 'lcs').map((item) => (
                <button
                  key={item}
                  type="button"
                  className={`${styles.segmentBtn} ${selectedMode === item ? styles.active : ''}`}
                  onClick={() => setSelectedMode(item)}
                >
                  {t(`messageSearch.mode.${item}`)}
                </button>
              ))}
            </div>

            <button className={styles.searchBtn} type="submit" disabled={articleIds?.length === 0}>
              {t('messageSearch.search')}
            </button>

            <select
              className={styles.resultLimitSelect}
              value={messageSearchResultLimit}
              onChange={(event) => setMessageSearchResultLimit(Number(event.target.value))}
              aria-label={t('settings.messageSearch.resultLimit')}
              title={t('settings.messageSearch.resultLimit')}
            >
              {RESULT_LIMITS.map((limit) => (
                <option key={limit} value={limit}>
                  {limit}
                </option>
              ))}
            </select>

            <input
              type="range"
              className={styles.columnSlider}
              min={180}
              max={900}
              step={10}
              value={messageSearchColumnWidth}
              onChange={(event) => setMessageSearchColumnWidth(Number(event.target.value))}
              aria-label={t('messageSearch.columnWidth')}
            />
          </div>
        </form>

        {data && (
          <div className={styles.resultCount}>
            {t('messageSearch.resultCount', { count: data.results.length })}
          </div>
        )}
      </div>

      {articleIds?.length === 0 && <div className={styles.empty}>{t('scopedMessageSearch.emptyScope')}</div>}
      {isLoading && <LoadingSpinner />}

      {isError && (
        <div className={styles.error}>
          <span>{t(FILTER_ERRORS[errorCode] || 'messageSearch.error')}</span>
          <button type="button" className={styles.retryBtn} onClick={() => refetch()}>
            {t('messageSearch.retry')}
          </button>
        </div>
      )}

      {!isLoading && data && data.results.length === 0 && (
        <div className={styles.empty}>{t('messageSearch.empty')}</div>
      )}

      {!isLoading && data && data.results.length > 0 && (
        <MessageSearchGrid results={data.results} columnWidth={messageSearchColumnWidth} />
      )}

      {showScrollTop && (
        <button
          type="button"
          className={styles.scrollTopBtn}
          onClick={handleScrollToTop}
          aria-label={t('messageSearch.scrollToTop')}
          title={t('messageSearch.scrollToTop')}
        >
          <ArrowUp size={20} />
        </button>
      )}
    </div>
  );
}
