import { useState, useEffect, useCallback } from 'react';
import { useSearchParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { X, ChevronLeft, ChevronRight, ExternalLink } from 'lucide-react';
import { useSearch } from '../../hooks/useSearch';
import { useSearchDialogStore } from '../../stores/search-dialog-store';
import { useAppStore } from '../../stores/app-store';
import { SearchResultGrid } from './SearchResultGrid';
import { LoadingSpinner } from '../common/LoadingSpinner';
import styles from './SearchDialog.module.css';

interface SearchDialogProps {
  query: string;
  onClose: () => void;
}

export function SearchDialog({ query, onClose }: SearchDialogProps) {
  const { t } = useTranslation();
  const page = useSearchDialogStore((s) => s.page);
  const setPage = useSearchDialogStore((s) => s.setPage);
  const [searchParams] = useSearchParams();
  const mainQuery = searchParams.get('q') || '';
  const [andMode, setAndMode] = useState(false);
  const { contentLanguage, excludedTags } = useAppStore();
  const pageSize = 30;

  const combinedQuery = andMode && mainQuery ? `${mainQuery} ${query}` : query;
  const baseQuery = contentLanguage !== 'all' ? `${combinedQuery} lang:${contentLanguage}` : combinedQuery;
  const excludeSuffix = excludedTags
    .filter((tag) => !query.includes(`-${tag}`))
    .map((tag) => `-${tag}`)
    .join(' ');
  const fullQuery = excludeSuffix ? `${baseQuery} ${excludeSuffix}` : baseQuery;

  const { data, isLoading } = useSearch(fullQuery, page, pageSize);

  const totalCount = data?.totalCount ?? 0;
  const totalPages = Math.ceil(totalCount / pageSize);
  const articles = data?.articles ?? [];

  const goNext = useCallback(() => {
    setPage(Math.min(page + 1, totalPages - 1));
  }, [page, totalPages, setPage]);

  const goPrev = useCallback(() => {
    setPage(Math.max(page - 1, 0));
  }, [page, setPage]);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      e.stopImmediatePropagation();
      if (e.key === 'Escape') { onClose(); return; }
      if (e.key === 'ArrowLeft') { e.preventDefault(); goPrev(); }
      if (e.key === 'ArrowRight') { e.preventDefault(); goNext(); }
    };
    window.addEventListener('keydown', handleKeyDown, true);
    return () => window.removeEventListener('keydown', handleKeyDown, true);
  }, [onClose, goNext, goPrev]);

  return (
    <div className={styles.overlay} onClick={onClose}>
      <div className={styles.dialog} onClick={(e) => e.stopPropagation()}>
        <div className={styles.header}>
          <div className={styles.queryLabel}>{query}</div>
          <div className={styles.countLabel}>
            {totalCount > 0 && t('home.results', { count: totalCount })}
          </div>
          {mainQuery && (
            <label className={styles.andToggle}>
              <span className={styles.andLabel}>{t('search.includeQuery', { query: mainQuery })}</span>
              <span className={styles.toggle}>
                <input
                  type="checkbox"
                  checked={andMode}
                  onChange={(e) => { setAndMode(e.target.checked); setPage(0); }}
                />
                <span className={styles.toggleTrack} />
              </span>
            </label>
          )}
          <div className={styles.headerSpacer} />
          <button
            className={styles.closeBtn}
            onClick={() => {
              const q = andMode && mainQuery ? `${mainQuery} ${query}` : query;
              const params = new URLSearchParams({ q });
              if (page > 0) params.set('p', String(page));
              window.open(`/?${params.toString()}`, '_blank');
            }}
          >
            <ExternalLink size={18} />
          </button>
          <button className={styles.closeBtn} onClick={onClose}>
            <X size={20} />
          </button>
        </div>

        <div className={styles.content}>
          {isLoading ? (
            <LoadingSpinner />
          ) : (
            <SearchResultGrid articles={articles} />
          )}
        </div>

        {totalPages > 1 && (
          <div className={styles.pagination}>
            <button disabled={page === 0} onClick={goPrev}>
              <ChevronLeft size={18} />
            </button>
            <span>{page + 1} / {totalPages}</span>
            <button disabled={page >= totalPages - 1} onClick={goNext}>
              <ChevronRight size={18} />
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
