import { useState, useEffect, useCallback, useRef } from 'react';
import { useNavigate, useLocation, useSearchParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useBookmarkGroups, useBookmarkArticles } from '../hooks/useBookmarks';
import { BookmarkGroupList } from '../components/bookmark/BookmarkGroupList';
import { LocalSearchSection } from '../components/search/LocalSearchSection';
import { SearchResultGrid } from '../components/search/SearchResultGrid';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import { InfiniteScroll } from '../components/common/InfiniteScroll';
import { useAllArticles } from '../hooks/useAllArticles';
import { useArticleTagSummary } from '../hooks/useArticleTagSummary';
import { useLocalArticleSearch } from '../hooks/useLocalArticleSearch';
import { useLocalSearchState } from '../hooks/useLocalSearchState';
import { useIsMobile } from '../hooks/useMediaQuery';
import { useAppStore } from '../stores/app-store';
import { usePaginationKeyboard } from '../hooks/usePaginationKeyboard';
import styles from './BookmarksPage.module.css';

const PAGE_SIZE = 30;

export function BookmarksPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const location = useLocation();
  const isMobile = useIsMobile();
  const { scrollMode } = useAppStore();

  const [selectedGroupId, setSelectedGroupId] = useState<number | undefined>(() => {
    const saved = sessionStorage.getItem(`bookmarks:group:${location.key}`);
    return saved ? parseInt(saved) : undefined;
  });
  const [visibleCount, setVisibleCount] = useState(() => {
    const saved = sessionStorage.getItem(`bookmarks:visible:${location.key}`);
    return saved ? parseInt(saved) : PAGE_SIZE;
  });
  const [searchParams, setSearchParams] = useSearchParams();
  const page = parseInt(searchParams.get('p') || '0');
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

  const { data: groups, isLoading: groupsLoading } = useBookmarkGroups();
  const { data: bookmarkArticles, isLoading: bookmarksLoading } =
    useBookmarkArticles(selectedGroupId);

  const allBookmarks = bookmarkArticles ?? [];
  const articleIds = allBookmarks.map((ba) => ba.Article);

  // Fetch ALL articles in bulk
  const { data: allArticles, isLoading: articlesLoading } = useAllArticles(
    `bookmarks-${selectedGroupId}`,
    articleIds.length > 0 ? articleIds : undefined,
  );

  const isLoading = groupsLoading || bookmarksLoading || articlesLoading;

  // Tag summary from ALL articles
  const tagSummary = useArticleTagSummary(allArticles ?? []);

  // Filter articles based on search query
  const filteredArticles = useLocalArticleSearch(allArticles ?? []);

  // Paginate/slice filtered results for display
  const totalPages = Math.ceil(filteredArticles.length / PAGE_SIZE);
  const displayArticles =
    scrollMode === 'infinite'
      ? filteredArticles.slice(0, visibleCount)
      : filteredArticles.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE);

  // Reset page if out of bounds
  useEffect(() => {
    if (page >= totalPages && totalPages > 0) setPage(totalPages - 1);
  }, [page, totalPages]);

  usePaginationKeyboard(page, totalPages, setPage, scrollMode === 'pagination');

  // Memoize reset callback
  const handleReset = useCallback(() => {
    navigate('/bookmarks', { replace: true });
  }, [navigate]);

  // Local search state
  const { selectedTags, searchBarRef, getSuggestions, handleTagToggle, resetTags } =
    useLocalSearchState({
      basePath: '/bookmarks',
      tagSummary,
      onReset: handleReset,
    });

  // Persist selectedGroupId and visibleCount to sessionStorage
  useEffect(() => {
    if (selectedGroupId !== undefined) {
      sessionStorage.setItem(`bookmarks:group:${location.key}`, String(selectedGroupId));
    } else {
      sessionStorage.removeItem(`bookmarks:group:${location.key}`);
    }
  }, [selectedGroupId, location.key]);

  useEffect(() => {
    sessionStorage.setItem(`bookmarks:visible:${location.key}`, String(visibleCount));
  }, [visibleCount, location.key]);

  // Reset selected tags and visible count when group changes
  const prevGroupRef = useRef(selectedGroupId);
  useEffect(() => {
    if (prevGroupRef.current !== selectedGroupId) {
      prevGroupRef.current = selectedGroupId;
      resetTags();
      setVisibleCount(PAGE_SIZE);
      setPage(0);
    }
  }, [selectedGroupId, resetTags]);

  const handleLoadMore = useCallback(() => {
    setVisibleCount((prev) => prev + PAGE_SIZE);
  }, []);

  const hasMore = scrollMode === 'infinite' && visibleCount < filteredArticles.length;

  return (
    <div>
      {isMobile && groups && (
        <BookmarkGroupList
          groups={groups}
          selectedId={selectedGroupId}
          onSelect={setSelectedGroupId}
        />
      )}

      {!isMobile && (
        <LocalSearchSection
          basePath="/bookmarks"
          searchBarRef={searchBarRef}
          getSuggestions={getSuggestions}
          tagSummary={tagSummary}
          selectedTags={selectedTags}
          onTagToggle={handleTagToggle}
          resultCount={filteredArticles.length}
          isLoading={isLoading}
          sticky
          headerContent={
            groups && (
              <BookmarkGroupList
                groups={groups}
                selectedId={selectedGroupId}
                onSelect={setSelectedGroupId}
              />
            )
          }
        />
      )}

      {isLoading && <LoadingSpinner />}
      {!isLoading && scrollMode === 'infinite' ? (
        <InfiniteScroll
          hasMore={hasMore}
          loading={false}
          onLoadMore={handleLoadMore}
        >
          <SearchResultGrid articles={displayArticles} />
        </InfiniteScroll>
      ) : (
        !isLoading && (
          <>
            <SearchResultGrid articles={displayArticles} />
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
        )
      )}
    </div>
  );
}
