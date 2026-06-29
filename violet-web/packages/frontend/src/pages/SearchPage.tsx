import { useState } from 'react';
import { useSearchParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useSearch } from '../hooks/useSearch';
import { SearchResultGrid } from '../components/search/SearchResultGrid';
import { SearchFilters } from '../components/search/SearchFilters';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import styles from './SearchPage.module.css';

export function SearchPage() {
  const { t } = useTranslation();
  const [searchParams] = useSearchParams();
  const query = searchParams.get('q') || '';
  const [page, setPage] = useState(0);
  const [language, setLanguage] = useState('all');

  const fullQuery =
    language !== 'all' ? `${query} lang:${language}` : query;
  const { data, isLoading } = useSearch(fullQuery || ' ', page);

  const totalPages = data ? Math.ceil(data.totalCount / data.pageSize) : 0;

  return (
    <div>
      <h2 className={styles.heading}>
        {t('home.heading')}
      </h2>
      <SearchFilters language={language} onLanguageChange={setLanguage} />
      {isLoading && <LoadingSpinner />}
      {data && (
        <>
          <p className={styles.count}>{t('home.results', { count: data.totalCount })}</p>
          <SearchResultGrid articles={data.articles} />
          {totalPages > 1 && (
            <div className={styles.pagination}>
              <button
                disabled={page === 0}
                onClick={() => setPage((p) => p - 1)}
              >
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
