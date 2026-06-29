import { useState, useMemo, useEffect, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import { useViewerStore } from '../../stores/viewer-store';
import { useIsBookmarked, useToggleBookmark } from '../../hooks/useBookmarks';
import { ViewerSettingsPanel } from './ViewerSettingsPanel';
import { PageThumbnailDialog } from './PageThumbnailDialog';
import { CropDialog } from './CropDialog';
import styles from './ViewerOverlay.module.css';

interface ViewerOverlayProps {
  galleryId: number;
  currentPage: number;
  totalPages: number;
  onPageChange: (page: number) => void;
  onClose: () => void;
  thumbnailUrls: string[];
  imageUrls: string[];
}

export function ViewerOverlay({
  galleryId,
  currentPage,
  totalPages,
  onPageChange,
  onClose,
  thumbnailUrls,
  imageUrls,
}: ViewerOverlayProps) {
  const { t } = useTranslation();
  const { showOverlay, showSettings, readDirection, twoPageMode, coverPageMode, toggleOverlay, toggleSettings, setTwoPageMode } = useViewerStore();
  const { data: isBookmarked } = useIsBookmarked(String(galleryId));
  const toggleBookmark = useToggleBookmark();
  const rtl = readDirection === 'rtl';
  const [showThumbnails, setShowThumbnails] = useState(false);
  const [showCropDialog, setShowCropDialog] = useState(false);

  const handleBookmarkToggle = useCallback(() => {
    toggleBookmark.mutate({ articleId: String(galleryId), isBookmarked: !!isBookmarked });
  }, [toggleBookmark, galleryId, isBookmarked]);

  // Keyboard shortcuts (single key, no modifiers)
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      // Ignore when typing in inputs or when dialogs are open
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;
      if (showThumbnails || showCropDialog) return;

      switch (e.key.toLowerCase()) {
        case 'h':
          e.preventDefault();
          toggleOverlay();
          break;
        case 's':
          e.preventDefault();
          toggleSettings();
          break;
        case 'b':
          e.preventDefault();
          if (!toggleBookmark.isPending) handleBookmarkToggle();
          break;
        case 't':
          e.preventDefault();
          setShowThumbnails(true);
          break;
        case 'c':
          e.preventDefault();
          setShowCropDialog(true);
          break;
        case 'd':
          e.preventDefault();
          setTwoPageMode(!twoPageMode);
          break;
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [toggleOverlay, toggleSettings, handleBookmarkToggle, toggleBookmark.isPending, showThumbnails, showCropDialog, setTwoPageMode, twoPageMode]);

  const visiblePages = useMemo(() => {
    if (!twoPageMode) return [currentPage];

    const pages: number[] = [];
    if (coverPageMode === 'cover') {
      if (currentPage === 0) {
        pages.push(0);
      } else {
        if (currentPage < totalPages) pages.push(currentPage);
        if (currentPage + 1 < totalPages) pages.push(currentPage + 1);
      }
    } else {
      const pairStart = Math.floor(currentPage / 2) * 2;
      if (pairStart < totalPages) pages.push(pairStart);
      if (pairStart + 1 < totalPages) pages.push(pairStart + 1);
    }
    return pages;
  }, [currentPage, twoPageMode, coverPageMode, totalPages]);

  const goNext = () => {
    if (!twoPageMode) {
      if (currentPage < totalPages - 1) onPageChange(currentPage + 1);
      return;
    }
    if (coverPageMode === 'cover') {
      if (currentPage === 0) {
        onPageChange(1);
      } else {
        const next = currentPage + 2;
        if (next < totalPages) onPageChange(next);
      }
    } else {
      const currentPairStart = Math.floor(currentPage / 2) * 2;
      const next = currentPairStart + 2;
      if (next < totalPages) onPageChange(next);
    }
  };

  const goPrev = () => {
    if (!twoPageMode) {
      if (currentPage > 0) onPageChange(currentPage - 1);
      return;
    }
    if (coverPageMode === 'cover') {
      if (currentPage <= 1) {
        onPageChange(0);
      } else {
        const prev = currentPage - 2;
        onPageChange(prev >= 1 ? prev : 0);
      }
    } else {
      const currentPairStart = Math.floor(currentPage / 2) * 2;
      const prev = currentPairStart - 2;
      if (prev >= 0) onPageChange(prev);
    }
  };

  const handleLeftTap = () => {
    rtl ? goNext() : goPrev();
  };

  const handleRightTap = () => {
    rtl ? goPrev() : goNext();
  };

  return (
    <>
      <div className={styles.tapZoneLeft} onClick={handleLeftTap} />
      <div className={styles.tapZoneCenter} onClick={toggleOverlay} />
      <div className={styles.tapZoneRight} onClick={handleRightTap} />

      <div
        className={`${styles.pageIndicator} ${showOverlay ? styles.pageIndicatorAboveSlider : ''}`}
        onClick={(e) => {
          e.stopPropagation();
          setShowThumbnails(true);
        }}
      >
        {t('viewer.pageInfo', { current: currentPage + 1, total: totalPages })}
      </div>

      {showOverlay && (
        <>
          <div className={styles.top}>
            <button className={styles.closeBtn} onClick={onClose}>
              {t('viewer.back')}
            </button>
            <button
              className={`${styles.bookmarkBtn} ${isBookmarked ? styles.bookmarked : ''}`}
              onClick={(e) => {
                e.stopPropagation();
                toggleBookmark.mutate({ articleId: String(galleryId), isBookmarked: !!isBookmarked });
              }}
              disabled={toggleBookmark.isPending}
              aria-label={isBookmarked ? t('article.bookmarked') : t('article.bookmark')}
            >
              {isBookmarked ? '★' : '☆'}
            </button>
            <button
              className={styles.cropBtn}
              onClick={(e) => {
                e.stopPropagation();
                setShowCropDialog(true);
              }}
              aria-label="Crop"
            >
              ✂
            </button>
            <div style={{ flex: 1 }} />
            <button
              className={styles.settingsBtn}
              onClick={(e) => {
                e.stopPropagation();
                toggleSettings();
              }}
            >
              {t('viewer.settings')}
            </button>
          </div>
          <div className={styles.shortcutHint}>
            <span><kbd>H</kbd> {t('viewer.settingsPanel.shortcuts.overlay')}</span>
            <span><kbd>S</kbd> {t('viewer.settingsPanel.shortcuts.settings')}</span>
            <span><kbd>B</kbd> {t('viewer.settingsPanel.shortcuts.bookmark')}</span>
            <span><kbd>T</kbd> {t('viewer.settingsPanel.shortcuts.thumbnails')}</span>
            <span><kbd>C</kbd> {t('viewer.settingsPanel.shortcuts.crop')}</span>
            <span><kbd>D</kbd> {t('viewer.settingsPanel.shortcuts.twoPage')}</span>
          </div>
          <div className={styles.bottom}>
            <input
              type="range"
              className={styles.slider}
              min={0}
              max={totalPages - 1}
              value={currentPage}
              onChange={(e) => onPageChange(Number(e.target.value))}
            />
          </div>
        </>
      )}
      {showSettings && <ViewerSettingsPanel />}
      {showThumbnails && (
        <PageThumbnailDialog
          thumbnailUrls={thumbnailUrls}
          currentPage={currentPage}
          totalPages={totalPages}
          twoPageMode={twoPageMode}
          coverPageMode={coverPageMode}
          onPageSelect={onPageChange}
          onClose={() => setShowThumbnails(false)}
        />
      )}
      {showCropDialog && (
        <CropDialog
          galleryId={galleryId}
          imageUrls={imageUrls}
          visiblePages={visiblePages}
          onClose={() => setShowCropDialog(false)}
        />
      )}
    </>
  );
}
