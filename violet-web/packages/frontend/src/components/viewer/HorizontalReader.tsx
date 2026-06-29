import { useRef, useEffect, useCallback } from 'react';
import { ViewerImage } from './ViewerImage';
import styles from './HorizontalReader.module.css';

const PREFETCH_RANGE = 5;

interface HorizontalReaderProps {
  imageUrls: string[];
  currentPage: number;
  onPageChange: (page: number) => void;
  rtl: boolean;
  galleryId: number;
}

export function HorizontalReader({
  imageUrls,
  currentPage,
  onPageChange,
  rtl,
  galleryId,
}: HorizontalReaderProps) {
  const containerRef = useRef<HTMLDivElement>(null);

  const scrollToPage = useCallback(
    (page: number) => {
      const container = containerRef.current;
      if (!container) return;
      const child = container.children[page] as HTMLElement;
      if (child) {
        child.scrollIntoView({ behavior: 'smooth', inline: 'start', block: 'nearest' });
      }
    },
    [],
  );

  useEffect(() => {
    scrollToPage(currentPage);
  }, [currentPage, scrollToPage]);

  // Detect snap position changes
  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    let timeout: ReturnType<typeof setTimeout>;
    const handleScroll = () => {
      clearTimeout(timeout);
      timeout = setTimeout(() => {
        const scrollPos = container.scrollLeft;
        const pageWidth = container.clientWidth;
        const page = Math.round(scrollPos / pageWidth);
        onPageChange(page);
      }, 100);
    };

    container.addEventListener('scroll', handleScroll, { passive: true });
    return () => {
      container.removeEventListener('scroll', handleScroll);
      clearTimeout(timeout);
    };
  }, [onPageChange]);

  // Click navigation
  const handleClick = useCallback(
    (e: React.MouseEvent<HTMLDivElement>) => {
      const container = containerRef.current;
      if (!container) return;
      const rect = container.getBoundingClientRect();
      const clickX = e.clientX - rect.left;
      const halfWidth = rect.width / 2;

      const goNext = () => {
        if (currentPage < imageUrls.length - 1) onPageChange(currentPage + 1);
      };
      const goPrev = () => {
        if (currentPage > 0) onPageChange(currentPage - 1);
      };

      if (clickX < halfWidth) {
        rtl ? goNext() : goPrev();
      } else {
        rtl ? goPrev() : goNext();
      }
    },
    [currentPage, imageUrls.length, onPageChange, rtl],
  );

  // Check if a page should be actively loaded (within prefetch range)
  const isPageActive = useCallback(
    (pageIndex: number) => {
      return Math.abs(pageIndex - currentPage) <= PREFETCH_RANGE;
    },
    [currentPage]
  );

  return (
    <div
      ref={containerRef}
      className={styles.container}
      style={{ direction: rtl ? 'rtl' : 'ltr' }}
      onClick={handleClick}
    >
      {imageUrls.map((url, i) => (
        <div key={i} className={styles.page}>
          <ViewerImage src={url} alt={`Page ${i + 1}`} active={isPageActive(i)} cacheKey={{ galleryId, page: i }} />
        </div>
      ))}
    </div>
  );
}
