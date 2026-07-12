import { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useQuery } from '@tanstack/react-query';
import { getDownloadEntries, getDownloads } from '../api/downloads';
import type { DownloadRecord } from '@violet-web/shared';
import { useAllArticles } from '../hooks/useAllArticles';
import { LocalSearchSection } from '../components/search/LocalSearchSection';
import { SearchResultGrid } from '../components/search/SearchResultGrid';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import { InfiniteScroll } from '../components/common/InfiniteScroll';
import { DownloadProgressProvider } from '../contexts/DownloadProgressContext';
import { useArticleTagSummary } from '../hooks/useArticleTagSummary';
import { useLocalArticleSearch } from '../hooks/useLocalArticleSearch';
import { useLocalSearchState } from '../hooks/useLocalSearchState';
import { useIsMobile } from '../hooks/useMediaQuery';
import { useAppStore } from '../stores/app-store';
import { usePaginationKeyboard } from '../hooks/usePaginationKeyboard';
import { useToastStore } from '../stores/toast-store';
import styles from './DownloadsPage.module.css';
import { DateRangeFilter } from '../components/search/DateRangeFilter';
import { updateDateParams } from '../components/search/date-range-model';
import { buildLocalDateDistribution, filterItemsByDateRange } from '../components/search/local-date-range-model';

const PAGE_SIZE = 30;

export function DownloadsPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const isMobile = useIsMobile();
  const addToast = useToastStore((s) => s.addToast);
  const { scrollMode } = useAppStore();

  const [searchParams, setSearchParams] = useSearchParams();
  const page = parseInt(searchParams.get('p') || '0');
  const from = searchParams.get('from') || undefined;
  const to = searchParams.get('to') || undefined;
  const setPage = useCallback(
    (updater: number | ((prev: number) => number)) => {
      const newPage = typeof updater === 'function' ? updater(page) : updater;
      const newParams = new URLSearchParams(searchParams);
      if (newPage === 0) {
        newParams.delete('p');
      } else {
        newParams.set('p', String(newPage));
      }
      setSearchParams(newParams);
    },
    [page, searchParams, setSearchParams],
  );
  const [visibleCount, setVisibleCount] = useState(PAGE_SIZE);

  // Fetch all download article IDs
  const { data: downloadEntries, isLoading: idsLoading } = useQuery({
    queryKey: ['downloads', 'ids'],
    queryFn: getDownloadEntries,
  });
  const articleIds = downloadEntries?.map((entry) => entry.articleId);

  // Fetch all articles in bulk
  const { data: allArticles, isLoading: articlesLoading } = useAllArticles(
    'downloads',
    articleIds,
  );

  // Also fetch current page downloads for progress tracking
  const { data: downloadData } = useQuery({
    queryKey: ['downloads', 'progress'],
    queryFn: () => getDownloads(0, 10000),
    refetchInterval: (query) => {
      const downloads = query.state.data?.downloads;
      if (downloads?.some((dl) => dl.Status === 'downloading')) {
        return 2000;
      }
      return false;
    },
  });

  const currentDownloads = downloadData?.downloads ?? [];

  // Build download progress map for context
  const downloadProgressMap = useMemo(() => {
    const map = new Map<string, DownloadRecord>();
    for (const dl of currentDownloads) {
      map.set(dl.Article, dl);
    }
    return map;
  }, [currentDownloads]);

  // Detect completion transitions and show toast
  const prevStatusRef = useRef<Map<number, string>>(new Map());
  useEffect(() => {
    const prevMap = prevStatusRef.current;
    for (const dl of currentDownloads) {
      const prev = prevMap.get(dl.Id);
      if (prev === 'downloading' && dl.Status === 'completed') {
        addToast(t('downloads.completeToast'), 'success');
      }
      if (prev === 'downloading' && dl.Status === 'failed') {
        addToast(t('downloads.failedToast'), 'error');
      }
    }
    const newMap = new Map<number, string>();
    for (const dl of currentDownloads) {
      newMap.set(dl.Id, dl.Status);
    }
    prevStatusRef.current = newMap;
  }, [currentDownloads, addToast, t]);

  const isLoading = idsLoading || articlesLoading;

  // Tag summary from ALL articles
  const tagSummary = useArticleTagSummary(allArticles ?? []);

  // Filter articles based on search query
  const searchFilteredArticles = useLocalArticleSearch(allArticles ?? []);
  const downloadDateByArticle = new Map(downloadEntries?.map((entry) => [entry.articleId, entry.date]));
  const dateDistribution = buildLocalDateDistribution(
    searchFilteredArticles.map((article) => downloadDateByArticle.get(String(article.Id)) ?? ''),
  );
  const filteredArticles = filterItemsByDateRange(
    searchFilteredArticles,
    (article) => downloadDateByArticle.get(String(article.Id)) ?? '',
    from,
    to,
  );

  // Paginate/slice filtered results for display
  const totalPages = Math.ceil(filteredArticles.length / PAGE_SIZE);
  const displayArticles =
    scrollMode === 'infinite'
      ? filteredArticles.slice(0, visibleCount)
      : filteredArticles.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE);

  usePaginationKeyboard(page, totalPages, setPage, scrollMode === 'pagination');

  const handleReset = useCallback(() => {
    navigate('/downloads', { replace: true });
  }, [navigate]);

  const { selectedTags, searchBarRef, getSuggestions, handleTagToggle } =
    useLocalSearchState({
      basePath: '/downloads',
      tagSummary,
      onReset: handleReset,
    });

  const handleLoadMore = useCallback(() => {
    setVisibleCount((prev) => prev + PAGE_SIZE);
  }, []);

  const hasMore = scrollMode === 'infinite' && visibleCount < filteredArticles.length;

  return (
    <div className={styles.page}>
      {!isMobile && (
        <LocalSearchSection
          basePath="/downloads"
          searchBarRef={searchBarRef}
          getSuggestions={getSuggestions}
          tagSummary={tagSummary}
          selectedTags={selectedTags}
          onTagToggle={handleTagToggle}
          resultCount={filteredArticles.length}
          isLoading={isLoading}
          sticky
          dateRangeContent={
            <DateRangeFilter
              compact
              query=""
              from={from}
              to={to}
              distributionData={dateDistribution}
              distributionLoading={isLoading}
              onCommit={(nextFrom, nextTo) =>
                setSearchParams(updateDateParams(searchParams, nextFrom, nextTo))
              }
            />
          }
        />
      )}

      <DownloadProgressProvider value={downloadProgressMap}>
        {scrollMode === 'infinite' ? (
          <>
            {isLoading && <LoadingSpinner />}
            {!isLoading && (
              <InfiniteScroll
                hasMore={hasMore}
                loading={false}
                onLoadMore={handleLoadMore}
              >
                <SearchResultGrid articles={displayArticles} />
              </InfiniteScroll>
            )}
          </>
        ) : (
          <>
            {isLoading && <LoadingSpinner />}
            {!isLoading && <SearchResultGrid articles={displayArticles} />}

            {totalPages > 1 && (
              <div className={styles.pagination}>
                <button disabled={page === 0} onClick={() => setPage((p) => p - 1)}>
                  {t('home.prev')}
                </button>
                <span>
                  {page + 1} / {totalPages}
                </span>
                <button
                  disabled={page >= totalPages - 1}
                  onClick={() => setPage((p) => p + 1)}
                >
                  {t('home.next')}
                </button>
              </div>
            )}
          </>
        )}
      </DownloadProgressProvider>
    </div>
  );
}
