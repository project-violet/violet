import { useCallback } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { SearchResultGrid } from '../components/search/SearchResultGrid';
import { LocalSearchSection } from '../components/search/LocalSearchSection';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import { useHot } from '../hooks/useHot';
import { useArticleTagSummary } from '../hooks/useArticleTagSummary';
import { useLocalArticleSearch } from '../hooks/useLocalArticleSearch';
import { useLocalSearchState } from '../hooks/useLocalSearchState';
import { usePaginationKeyboard } from '../hooks/usePaginationKeyboard';
import { useIsMobile } from '../hooks/useMediaQuery';
import { useAppStore } from '../stores/app-store';
import type { HotPeriod } from '../api/hot';
import styles from './HotPage.module.css';

const PERIODS: HotPeriod[] = ['daily', 'weekly', 'monthly', 'alltime'];
const PERIOD_LABEL_KEYS: Record<HotPeriod, string> = {
  daily: 'hot.daily',
  weekly: 'hot.weekly',
  monthly: 'hot.monthly',
  alltime: 'hot.alltime',
};

const PAGE_SIZE = 50;

export function HotPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const isMobile = useIsMobile();
  const { scrollMode } = useAppStore();
  const [searchParams, setSearchParams] = useSearchParams();

  const period = (searchParams.get('period') as HotPeriod) || 'daily';
  const page = parseInt(searchParams.get('p') || '0');

  const setPeriod = useCallback(
    (newPeriod: HotPeriod) => {
      const newParams = new URLSearchParams(searchParams);
      if (newPeriod === 'daily') {
        newParams.delete('period');
      } else {
        newParams.set('period', newPeriod);
      }
      newParams.delete('p');
      newParams.delete('q');
      setSearchParams(newParams);
    },
    [searchParams, setSearchParams],
  );

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

  const { articles, rankInfo, isLoading, error, enabled, hasMore } = useHot(period, page);

  // Tag summary + local search filtering
  const tagSummary = useArticleTagSummary(articles);
  const filteredArticles = useLocalArticleSearch(articles);

  // Build filtered rankInfo (preserve only articles that pass the local filter)
  const filteredRankInfo = rankInfo;

  const totalPages = hasMore ? page + 2 : page + 1;
  usePaginationKeyboard(page, totalPages, setPage, scrollMode === 'pagination');

  const handleReset = useCallback(() => {
    navigate('/hot', { replace: true });
  }, [navigate]);

  const { selectedTags, searchBarRef, getSuggestions, handleTagToggle } =
    useLocalSearchState({
      basePath: '/hot',
      tagSummary,
      onReset: handleReset,
      preserveParams: ['period', 'p'],
    });

  if (!enabled) {
    return (
      <div className={styles.page}>
        <h2 className={styles.heading}>{t('hot.heading')}</h2>
        <div className={styles.setupMessage}>
          <p>{t('hot.setupRequired')}</p>
          <p>{t('hot.setupHint')}</p>
        </div>
      </div>
    );
  }

  const periodSelector = (
    <div className={styles.periodTabs}>
      {PERIODS.map((p) => (
        <button
          key={p}
          className={`${styles.periodTab} ${period === p ? styles.active : ''}`}
          onClick={() => setPeriod(p)}
        >
          {t(PERIOD_LABEL_KEYS[p])}
        </button>
      ))}
    </div>
  );

  return (
    <div className={styles.page}>
      {!isMobile && (
        <LocalSearchSection
          basePath="/hot"
          searchBarRef={searchBarRef}
          getSuggestions={getSuggestions}
          tagSummary={tagSummary}
          selectedTags={selectedTags}
          onTagToggle={handleTagToggle}
          resultCount={filteredArticles.length}
          isLoading={isLoading}
          sticky
          headerContent={periodSelector}
        />
      )}

      {isMobile && periodSelector}

      {error && <div className={styles.errorMessage}>{t('hot.error')}</div>}

      {isLoading && <LoadingSpinner />}

      {!isLoading && !error && (
        <SearchResultGrid articles={filteredArticles} rankInfo={filteredRankInfo} />
      )}

      {(hasMore || page > 0) && (
        <div className={styles.pagination}>
          <button disabled={page === 0} onClick={() => setPage((p) => p - 1)}>
            {t('home.prev')}
          </button>
          <span>{page + 1}</span>
          <button disabled={!hasMore} onClick={() => setPage((p) => p + 1)}>
            {t('home.next')}
          </button>
        </div>
      )}
    </div>
  );
}
