import { useRef, useEffect, useMemo, useCallback, useState } from 'react';
import { Outlet, useSearchParams, useLocation } from 'react-router';
import { useTranslation } from 'react-i18next';
import { ChevronDown, ChevronUp } from 'lucide-react';
import { Sidebar } from './Sidebar';
import { BottomNav } from './BottomNav';
import { SearchBar, type SearchBarRef } from '../search/SearchBar';
import { SearchDialog } from '../search/SearchDialog';
import { TagChips } from '../search/TagChips';
import { DateRangeFilter } from '../search/DateRangeFilter';
import { updateDateParams } from '../search/date-range-model';
import { Toast } from '../common/Toast';
import { useIsMobile, useIsDesktop } from '../../hooks/useMediaQuery';
import { useSearchTagSummary } from '../../hooks/useSearchTagSummary';
import { useAppStore } from '../../stores/app-store';
import { useSearchDialogStore, restoreSearchDialogFromUrl } from '../../stores/search-dialog-store';
import styles from './AppShell.module.css';

export function AppShell() {
  const isMobile = useIsMobile();
  const isDesktop = useIsDesktop();
  const { t } = useTranslation();
  const location = useLocation();
  const [searchParams, setSearchParams] = useSearchParams();
  const query = searchParams.get('q') || '';
  const dateRange = {
    from: searchParams.get('from') || undefined,
    to: searchParams.get('to') || undefined,
  };
  const dialogQuery = useSearchDialogStore((s) => s.query);
  const closeDialog = useSearchDialogStore((s) => s.close);
  const { contentLanguage, viewMode, setViewMode, cardMinWidth, setCardMinWidth, excludedTags } = useAppStore();
  const [showAllSearchTags, setShowAllSearchTags] = useState(false);
  const searchBarRef = useRef<SearchBarRef>(null);
  const contentRef = useRef<HTMLElement>(null);

  // Flag to prevent saving scroll position while restoring
  const isRestoringRef = useRef(false);

  // Restore search dialog from URL on mount (back from viewer)
  useEffect(() => {
    restoreSearchDialogFromUrl();
  }, []);

  // Save scroll position on scroll (keyed by location.key)
  useEffect(() => {
    const content = contentRef.current;
    if (!content) return;
    const handleScroll = () => {
      if (isRestoringRef.current) return;
      sessionStorage.setItem(`scroll:${location.key}`, String(content.scrollTop));
    };
    content.addEventListener('scroll', handleScroll, { passive: true });
    return () => content.removeEventListener('scroll', handleScroll);
  }, [location.key]);

  // Restore saved scroll position or scroll to top on navigation
  useEffect(() => {
    const content = contentRef.current;
    if (!content) return;

    const saved = sessionStorage.getItem(`scroll:${location.key}`);
    const target = saved ? parseInt(saved) : 0;

    content.scrollTo(0, target);

    if (!saved) return;

    // Retry restoration as content renders (images, query data, etc.)
    isRestoringRef.current = true;

    // Fixed-interval retries for quick restoration
    const timers = [50, 100, 200, 500].map((delay) =>
      setTimeout(() => content.scrollTo(0, target), delay),
    );

    // Also observe content size changes for pages with async data loading
    // (e.g., bookmarks/history where article data loads after initial render)
    let observer: ResizeObserver | undefined;
    if (typeof ResizeObserver !== 'undefined') {
      observer = new ResizeObserver(() => {
        if (isRestoringRef.current) {
          content.scrollTo(0, target);
        }
      });
      // Observe the content element itself for scroll height changes
      observer.observe(content);
    }

    const done = setTimeout(() => {
      observer?.disconnect();
      isRestoringRef.current = false;
    }, 1500);

    return () => {
      timers.forEach(clearTimeout);
      clearTimeout(done);
      observer?.disconnect();
      isRestoringRef.current = false;
    };
  }, [location.key]);

  const showSearchBar = location.pathname === '/';
  const enableShellSearch = isDesktop && showSearchBar;
  const baseQuery = contentLanguage !== 'all' ? `${query} lang:${contentLanguage}` : query;
  const excludeSuffix = excludedTags
    .filter((tag) => !query.includes(`-${tag}`))
    .map((tag) => `-${tag}`)
    .join(' ');
  const fullQuery = excludeSuffix ? `${baseQuery} ${excludeSuffix}` : baseQuery;
  const { data: tagSummary = [] } = useSearchTagSummary(fullQuery || ' ', 30, {
    enabled: enableShellSearch,
  });
  const selectedTags = useMemo(() => new Set(query.trim().split(/\s+/).filter(Boolean)), [query]);

  const handleTagToggle = useCallback(
    (display: string) => {
      const tokens = query.trim().split(/\s+/).filter(Boolean);
      const nextTokens = tokens.includes(display)
        ? tokens.filter((token) => token !== display)
        : [...tokens, display];

      const nextParams = new URLSearchParams(searchParams);
      nextParams.delete('p');
      if (nextTokens.length > 0) {
        nextParams.set('q', nextTokens.join(' '));
      } else {
        nextParams.delete('q');
      }
      setSearchParams(nextParams);
    },
    [query, searchParams, setSearchParams],
  );

  // Handle "/" key to focus search bar on home page
  // Note: bookmarks and history pages will handle "/" key themselves
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement;
      // Ignore if user is typing in an input or textarea
      if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA') {
        return;
      }

      // Only trigger on home page (bookmarks/history have their own search bars)
      if (e.key === '/' && location.pathname === '/') {
        e.preventDefault();
        searchBarRef.current?.focus();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [location.pathname]);

  return (
    <div className={styles.shell}>
      {isDesktop && <Sidebar />}
      <div className={styles.mainArea}>
        {isDesktop && showSearchBar && (
          <div className={styles.searchBar}>
            <div className={styles.searchControls}>
            <div className={styles.searchColumn}>
              <SearchBar ref={searchBarRef} />
            </div>
            <div className={styles.dateRangeInline}>
              <DateRangeFilter
                compact
                query={fullQuery || ' '}
                from={dateRange.from}
                to={dateRange.to}
                onCommit={(from, to) =>
                  setSearchParams(updateDateParams(searchParams, from, to))
                }
              />
            </div>
            <input
              type="range"
              className={styles.cardSizeSlider}
              min={120}
              max={350}
              step={10}
              value={cardMinWidth}
              onChange={(e) => setCardMinWidth(Number(e.target.value))}
            />
            <label className={styles.viewSwitch} title={viewMode === 'grid' ? 'Detail view' : 'Grid view'}>
              <span className={styles.switchLabel}>▦</span>
              <input
                type="checkbox"
                className={styles.switchInput}
                checked={viewMode === 'detail'}
                onChange={() => setViewMode(viewMode === 'grid' ? 'detail' : 'grid')}
              />
              <span className={styles.switchTrack}>
                <span className={styles.switchThumb} />
              </span>
              <span className={styles.switchLabel}>☰</span>
            </label>
            </div>
            {tagSummary.length > 0 && (
              <div className={styles.tagRow}>
                <TagChips
                  tags={tagSummary}
                  selectedTags={selectedTags}
                  onToggle={handleTagToggle}
                  className={`${styles.searchTags} ${showAllSearchTags ? '' : styles.searchTagsCollapsed}`}
                />
                <button
                  type="button"
                  className={styles.tagToggleBtn}
                  onClick={() => setShowAllSearchTags((value) => !value)}
                  aria-label={t(showAllSearchTags ? 'search.collapseTags' : 'search.expandTags')}
                  title={t(showAllSearchTags ? 'search.collapseTags' : 'search.expandTags')}
                >
                  {showAllSearchTags ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                </button>
              </div>
            )}
          </div>
        )}
        <main ref={contentRef} className={styles.content}>
          <Outlet />
        </main>
      </div>
      {isMobile && <BottomNav />}
      {dialogQuery && (
        <SearchDialog query={dialogQuery} onClose={closeDialog} />
      )}
      <Toast />
    </div>
  );
}
