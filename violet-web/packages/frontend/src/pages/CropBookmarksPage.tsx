import { useCallback, useState, useEffect, useRef } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useCropBookmarks, useDeleteCropBookmark } from '../hooks/useBookmarks';
import { useUserCropBookmarks } from '../hooks/useUserCropBookmarks';
import { CropBookmarkGrid } from '../components/bookmark/CropBookmarkGrid';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import { LocalSearchSection } from '../components/search/LocalSearchSection';
import { useQuery } from '@tanstack/react-query';
import { getArticlesBatch } from '../api/content';
import { useArticleTagSummary } from '../hooks/useArticleTagSummary';
import { useLocalArticleSearch } from '../hooks/useLocalArticleSearch';
import { useLocalSearchState } from '../hooks/useLocalSearchState';
import { useIsMobile } from '../hooks/useMediaQuery';
import { useAppStore } from '../stores/app-store';
import styles from './CropBookmarksPage.module.css';
import { DateRangeFilter } from '../components/search/DateRangeFilter';
import { updateDateParams } from '../components/search/date-range-model';
import { buildLocalDateDistribution, filterItemsByDateRange } from '../components/search/local-date-range-model';

export function CropBookmarksPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const isMobile = useIsMobile();
  const [searchParams, setSearchParams] = useSearchParams();
  const from = searchParams.get('from') || undefined;
  const to = searchParams.get('to') || undefined;

  const { data: cropBookmarks, isLoading } = useCropBookmarks();
  const deleteCropMutation = useDeleteCropBookmark();
  const cropColumnWidth = useAppStore((s) => s.cropColumnWidth);
  const setCropColumnWidth = useAppStore((s) => s.setCropColumnWidth);

  const [showUserBookmarks, setShowUserBookmarks] = useState(false);
  const { data: userCropBookmarks, isLoading: isUserLoading } =
    useUserCropBookmarks(showUserBookmarks);

  const handleDelete = useCallback(
    (id: number) => {
      if (id < 0) return; // user bookmarks are read-only
      deleteCropMutation.mutate(id);
    },
    [deleteCropMutation],
  );

  const displayCrops = showUserBookmarks
    ? (userCropBookmarks ?? [])
    : (cropBookmarks ?? []);
  const loading = showUserBookmarks ? isUserLoading : isLoading;

  // Fetch all articles in bulk for tag summary
  const uniqueArticleIds = [...new Set(displayCrops.map((crop) => crop.Article))];
  const { data: articles = [] } = useQuery({
    queryKey: ['articlesBatch', uniqueArticleIds],
    queryFn: () => getArticlesBatch(uniqueArticleIds),
    enabled: uniqueArticleIds.length > 0,
  });

  const tagSummary = useArticleTagSummary(articles);
  const filteredArticles = useLocalArticleSearch(articles);

  const handleReset = useCallback(() => {
    navigate('/crop-bookmarks', { replace: true });
  }, [navigate]);

  const { selectedTags, searchBarRef, getSuggestions, handleTagToggle, resetTags } =
    useLocalSearchState({
      basePath: '/crop-bookmarks',
      tagSummary,
      onReset: handleReset,
    });

  // Reset tags when showUserBookmarks changes
  const prevShowUserRef = useRef(showUserBookmarks);
  useEffect(() => {
    if (prevShowUserRef.current !== showUserBookmarks) {
      prevShowUserRef.current = showUserBookmarks;
      resetTags();
    }
  }, [showUserBookmarks, resetTags]);

  // Filter crops based on filtered articles
  const filteredArticleIds = new Set(filteredArticles.map((a) => a.Id));
  const tagFilteredCrops = displayCrops.filter((crop) =>
    filteredArticleIds.has(crop.Article),
  );
  const dateDistribution = buildLocalDateDistribution(
    showUserBookmarks ? [] : tagFilteredCrops.map((crop) => crop.DateTime),
  );
  const filteredCrops = showUserBookmarks
    ? tagFilteredCrops
    : filterItemsByDateRange(tagFilteredCrops, (crop) => crop.DateTime, from, to);

  const cropControls = (
    <>
      <label className={styles.toggleRow}>
        <span className={styles.toggleLabel}>{t('crop.userBookmarks')}</span>
        <span className={styles.toggle}>
          <input
            type="checkbox"
            checked={showUserBookmarks}
            onChange={(e) => setShowUserBookmarks(e.target.checked)}
          />
          <span className={styles.toggleTrack} />
        </span>
      </label>
      <input
        type="range"
        className={styles.sizeSlider}
        min={120}
        max={400}
        step={10}
        value={cropColumnWidth}
        onChange={(e) => setCropColumnWidth(Number(e.target.value))}
      />
    </>
  );

  return (
    <div>
      {isMobile && <div className={styles.headerControls}>{cropControls}</div>}

      {!isMobile && (
        <LocalSearchSection
          basePath="/crop-bookmarks"
          searchBarRef={searchBarRef}
          getSuggestions={getSuggestions}
          tagSummary={tagSummary}
          selectedTags={selectedTags}
          onTagToggle={handleTagToggle}
          resultCount={filteredCrops.length}
          isLoading={loading}
          showViewControls={false}
          sticky
          extraControls={cropControls}
          dateRangeContent={!showUserBookmarks ? (
            <DateRangeFilter
              compact
              query=""
              from={from}
              to={to}
              distributionData={dateDistribution}
              distributionLoading={loading}
              onCommit={(nextFrom, nextTo) =>
                setSearchParams(updateDateParams(searchParams, nextFrom, nextTo))
              }
            />
          ) : undefined}
        />
      )}

      {loading && <LoadingSpinner />}
      {!loading && (
        <CropBookmarkGrid
          crops={filteredCrops}
          columnWidth={cropColumnWidth}
          onDelete={handleDelete}
        />
      )}
    </div>
  );
}
