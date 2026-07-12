import { useState, useCallback } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useQuery } from '@tanstack/react-query';
import { getHistoryEntries } from '../api/history';
import { useAllArticles } from '../hooks/useAllArticles';
import { LocalSearchSection } from '../components/search/LocalSearchSection';
import { SearchResultGrid } from '../components/search/SearchResultGrid';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import { InfiniteScroll } from '../components/common/InfiniteScroll';
import { useArticleTagSummary } from '../hooks/useArticleTagSummary';
import { useLocalArticleSearch } from '../hooks/useLocalArticleSearch';
import { useLocalSearchState } from '../hooks/useLocalSearchState';
import { useIsMobile } from '../hooks/useMediaQuery';
import { useAppStore } from '../stores/app-store';
import { usePaginationKeyboard } from '../hooks/usePaginationKeyboard';
import styles from './HistoryPage.module.css';
import { DateRangeFilter } from '../components/search/DateRangeFilter';
import { updateDateParams } from '../components/search/date-range-model';
import { buildLocalDateDistribution, filterItemsByDateRange } from '../components/search/local-date-range-model';

const PAGE_SIZE = 30;

export function HistoryPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const isMobile = useIsMobile();
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

  // Fetch all history article IDs
  const { data: historyEntries, isLoading: idsLoading } = useQuery({
    queryKey: ['readHistory', 'ids'],
    queryFn: getHistoryEntries,
  });
  const articleIds = historyEntries?.map((entry) => entry.articleId);

  // Fetch all articles in bulk
  const { data: allArticles, isLoading: articlesLoading } = useAllArticles(
    'readHistory',
    articleIds,
  );

  const isLoading = idsLoading || articlesLoading;

  // Tag summary from ALL articles
  const tagSummary = useArticleTagSummary(allArticles ?? []);

  // Filter articles based on search query
  const searchFilteredArticles = useLocalArticleSearch(allArticles ?? []);
  const historyDateByArticle = new Map(historyEntries?.map((entry) => [entry.articleId, entry.date]));
  const dateDistribution = buildLocalDateDistribution(
    searchFilteredArticles.map((article) => historyDateByArticle.get(String(article.Id)) ?? ''),
  );
  const filteredArticles = filterItemsByDateRange(
    searchFilteredArticles,
    (article) => historyDateByArticle.get(String(article.Id)) ?? '',
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
    navigate('/history', { replace: true });
  }, [navigate]);

  const { selectedTags, searchBarRef, getSuggestions, handleTagToggle } =
    useLocalSearchState({
      basePath: '/history',
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
          basePath="/history"
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
    </div>
  );
}
