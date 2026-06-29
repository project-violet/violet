import { useEffect, useCallback, useMemo, useState } from 'react';
import { ViewerImage } from './ViewerImage';
import styles from './PagedReader.module.css';

const PREFETCH_RANGE = 5;

interface PagedReaderProps {
  imageUrls: string[];
  currentPage: number;
  onPageChange: (page: number) => void;
  rtl: boolean;
  twoPageMode: boolean;
  coverPageMode: 'cover' | 'normal';
  galleryId: number;
}

export function PagedReader({
  imageUrls,
  currentPage,
  onPageChange,
  rtl,
  twoPageMode,
  coverPageMode,
  galleryId,
}: PagedReaderProps) {
  const [containerRef, setContainerRef] = useState<HTMLDivElement | null>(null);

  // Calculate which pages should be visible
  const visiblePageIndices = useMemo(() => {
    if (!twoPageMode) {
      return new Set([currentPage]);
    }

    const visible = new Set<number>();

    if (coverPageMode === 'cover') {
      if (currentPage === 0) {
        visible.add(0);
      } else {
        const firstPage = currentPage;
        const secondPage = currentPage + 1;

        if (firstPage < imageUrls.length) visible.add(firstPage);
        if (secondPage < imageUrls.length) visible.add(secondPage);
      }
    } else {
      const pairIndex = Math.floor(currentPage / 2);
      const firstPage = pairIndex * 2;
      const secondPage = firstPage + 1;

      if (firstPage < imageUrls.length) visible.add(firstPage);
      if (secondPage < imageUrls.length) visible.add(secondPage);
    }

    return visible;
  }, [currentPage, twoPageMode, coverPageMode, imageUrls.length]);

  // Get ordered visible pages for rendering
  const orderedVisiblePages = useMemo(() => {
    const pages = Array.from(visiblePageIndices).sort((a, b) => a - b);
    return rtl && pages.length === 2 ? [pages[1], pages[0]] : pages;
  }, [visiblePageIndices, rtl]);

  // Navigate to next/prev page
  const goNext = useCallback(() => {
    if (!twoPageMode) {
      if (currentPage < imageUrls.length - 1) {
        onPageChange(currentPage + 1);
      }
      return;
    }

    // Two-page mode: always jump by 2 pages (one spread)
    if (coverPageMode === 'cover') {
      if (currentPage === 0) {
        // Cover -> first spread [1,2]
        onPageChange(1);
      } else {
        // Next spread: always +2
        const next = currentPage + 2;
        if (next < imageUrls.length) {
          onPageChange(next);
        }
      }
    } else {
      // Normal mode: normalize to even page, then +2
      const currentPairStart = Math.floor(currentPage / 2) * 2;
      const next = currentPairStart + 2;
      if (next < imageUrls.length) {
        onPageChange(next);
      }
    }
  }, [currentPage, imageUrls.length, twoPageMode, coverPageMode, onPageChange]);

  const goPrev = useCallback(() => {
    if (!twoPageMode) {
      if (currentPage > 0) {
        onPageChange(currentPage - 1);
      }
      return;
    }

    // Two-page mode: always jump by 2 pages (one spread)
    if (coverPageMode === 'cover') {
      if (currentPage <= 1) {
        // First spread or cover -> cover
        onPageChange(0);
      } else {
        // Previous spread: always -2
        const prev = currentPage - 2;
        if (prev >= 1) {
          onPageChange(prev);
        } else {
          onPageChange(0);
        }
      }
    } else {
      // Normal mode: normalize to even page, then -2
      const currentPairStart = Math.floor(currentPage / 2) * 2;
      const prev = currentPairStart - 2;
      if (prev >= 0) {
        onPageChange(prev);
      }
    }
  }, [currentPage, twoPageMode, coverPageMode, onPageChange]);

  // Keyboard navigation
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'ArrowRight') {
        e.preventDefault();
        rtl ? goPrev() : goNext();
      } else if (e.key === 'ArrowLeft') {
        e.preventDefault();
        rtl ? goNext() : goPrev();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [goNext, goPrev, rtl]);

  // Click navigation
  const handleClick = useCallback(
    (e: React.MouseEvent<HTMLDivElement>) => {
      if (!containerRef) return;
      const rect = containerRef.getBoundingClientRect();
      const clickX = e.clientX - rect.left;
      const halfWidth = rect.width / 2;

      if (clickX < halfWidth) {
        rtl ? goNext() : goPrev();
      } else {
        rtl ? goPrev() : goNext();
      }
    },
    [containerRef, goNext, goPrev, rtl],
  );

  const isSinglePage = visiblePageIndices.size === 1;
  const isCoverPage = twoPageMode && isSinglePage && currentPage === 0;
  const isLastSinglePage = twoPageMode && isSinglePage && currentPage > 0;

  // Check if a page should be actively loaded (within prefetch range)
  const isPageActive = useCallback(
    (pageIndex: number) => {
      return Math.abs(pageIndex - currentPage) <= PREFETCH_RANGE;
    },
    [currentPage]
  );

  return (
    <div
      ref={setContainerRef}
      className={`${styles.container} ${twoPageMode ? styles.twoPage : ''} ${isCoverPage ? styles.coverPage : ''} ${isLastSinglePage ? styles.lastSinglePage : ''}`}
      onClick={handleClick}
      data-rtl={rtl}
    >
      {/* Render ALL pages, but only load images within prefetch range */}
      {imageUrls.map((url, index) => (
        <div
          key={index}
          className={styles.pageWrapper}
          style={{
            display: visiblePageIndices.has(index) ? 'flex' : 'none',
            order: orderedVisiblePages.indexOf(index),
          }}
        >
          <ViewerImage
            src={url}
            alt={`Page ${index + 1}`}
            active={isPageActive(index)}
            cacheKey={{ galleryId, page: index }}
          />
        </div>
      ))}
    </div>
  );
}
