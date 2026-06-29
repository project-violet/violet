import { FormEvent, type KeyboardEvent, useCallback, useEffect, useRef, useState } from 'react';
import { useSearchParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import type { MessageSearchMode } from '@violet-web/shared';
import { ArrowUp, Search } from 'lucide-react';
import { useAppStore } from '../stores/app-store';
import { useMessageSearch } from '../hooks/useMessageSearch';
import { useMessageSearchHistory, useRecordMessageSearchHistory } from '../hooks/useMessageSearchHistory';
import { MessageSearchGrid } from '../components/message-search/MessageSearchGrid';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import styles from './MessageSearchPage.module.css';

const MODES: MessageSearchMode[] = ['contains', 'similar', 'lcs'];
const RESULT_LIMITS = [25, 50, 100, 200, 500];

function isMessageSearchMode(value: string): value is MessageSearchMode {
  return MODES.includes(value as MessageSearchMode);
}

export function MessageSearchPage() {
  const { t } = useTranslation();
  const pageRef = useRef<HTMLDivElement>(null);
  const [searchParams, setSearchParams] = useSearchParams();
  const queryFromUrl = searchParams.get('q') || '';
  const modeFromUrl = searchParams.get('mode') || 'contains';
  const mode: MessageSearchMode = isMessageSearchMode(modeFromUrl)
    ? modeFromUrl
    : 'contains';

  const {
    messageSearchEnabled,
    messageSearchServerUrl,
    messageSearchResultLimit,
    messageSearchColumnWidth,
    setMessageSearchResultLimit,
    setMessageSearchColumnWidth,
  } = useAppStore();

  const [inputValue, setInputValue] = useState(queryFromUrl);
  const [selectedMode, setSelectedMode] = useState<MessageSearchMode>(mode);
  const [isHistoryOpen, setIsHistoryOpen] = useState(false);
  const [highlightedHistoryIndex, setHighlightedHistoryIndex] = useState(0);
  const [showScrollTop, setShowScrollTop] = useState(false);

  const { data, isLoading, isError, refetch } = useMessageSearch(
    queryFromUrl,
    mode,
    messageSearchResultLimit,
    messageSearchServerUrl,
  );
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
    return pageRef.current?.closest<HTMLElement>('main') ?? null;
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

  useEffect(() => {
    document.title = queryFromUrl
      ? `${queryFromUrl} - ${t('messageSearch.heading')}`
      : `${t('messageSearch.heading')} - Violet`;
    return () => { document.title = 'Violet'; };
  }, [queryFromUrl, t]);

  const executeSearch = (query: string) => {
    const q = query.trim();
    if (!q) return;

    const params: Record<string, string> = { q };
    if (selectedMode !== 'contains') params.mode = selectedMode;
    recordHistory.mutate(q);
    setSearchParams(params);
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
                aria-controls="message-search-history"
                aria-activedescendant={
                  isHistoryOpen && historyItems.length > 0
                    ? `message-search-history-${highlightedHistoryIndex}`
                    : undefined
                }
              />
              {isHistoryOpen && historyItems.length > 0 && (
                <div
                  id="message-search-history"
                  className={styles.historyDropdown}
                  role="listbox"
                >
                  <div className={styles.historyHeader}>
                    {t('messageSearch.searchHistory')}
                  </div>
                  {historyItems.map((item, index) => (
                    <button
                      key={item.query}
                      id={`message-search-history-${index}`}
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

            <div className={styles.segmented}>
              {MODES.map((item) => (
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

            <button className={styles.searchBtn} type="submit">
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

      {isLoading && <LoadingSpinner />}

      {isError && (
        <div className={styles.error}>
          <span>{t('messageSearch.error')}</span>
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
