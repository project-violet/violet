import { useRef, useEffect, useCallback } from 'react';
import { ViewerImage } from './ViewerImage';
import styles from './VerticalReader.module.css';

const PREFETCH_RANGE = 5;

interface VerticalReaderProps {
  imageUrls: string[];
  currentPage: number;
  onPageChange: (page: number) => void;
  onTap: () => void;
  padding: number;
  galleryId: number;
}

export function VerticalReader({
  imageUrls,
  currentPage,
  onPageChange,
  onTap,
  padding,
  galleryId,
}: VerticalReaderProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const imageRefs = useRef<(HTMLDivElement | null)[]>([]);
  const isScrolling = useRef(false);
  const observedPageChange = useRef<number | null>(null);

  // Track current page via IntersectionObserver
  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    const observer = new IntersectionObserver(
      (entries) => {
        if (isScrolling.current) return;
        for (const entry of entries) {
          if (entry.isIntersecting) {
            const idx = Number(entry.target.getAttribute('data-page'));
            if (!isNaN(idx)) {
              observedPageChange.current = idx;
              onPageChange(idx);
            }
            break;
          }
        }
      },
      {
        root: container,
        threshold: 0.5,
      },
    );

    imageRefs.current.forEach((el) => {
      if (el) observer.observe(el);
    });

    return () => observer.disconnect();
  }, [imageUrls.length, onPageChange]);

  const scrollToPage = useCallback((page: number) => {
    const el = imageRefs.current[page];
    if (el) {
      isScrolling.current = true;
      el.scrollIntoView({ behavior: 'smooth', block: 'start' });
      setTimeout(() => {
        isScrolling.current = false;
      }, 500);
    }
  }, []);

  // Scroll to page when currentPage changes externally (e.g., slider)
  useEffect(() => {
    if (observedPageChange.current === currentPage) {
      observedPageChange.current = null;
      return;
    }
    scrollToPage(currentPage);
  }, [currentPage, scrollToPage]);

  // Check if a page should be actively loaded (within prefetch range)
  const isPageActive = useCallback(
    (pageIndex: number) => {
      return Math.abs(pageIndex - currentPage) <= PREFETCH_RANGE;
    },
    [currentPage]
  );

  const handleClick = useCallback(
    (event: React.MouseEvent<HTMLDivElement>) => {
      const target = event.target as HTMLElement;
      if (target.closest('button, a, input')) return;
      onTap();
    },
    [onTap],
  );

  return (
    <div ref={containerRef} className={styles.container} onClick={handleClick}>
      {imageUrls.map((url, i) => (
        <div
          key={i}
          ref={(el) => { imageRefs.current[i] = el; }}
          data-page={i}
          className={styles.page}
          style={{ padding: `${padding}px 0` }}
        >
          <ViewerImage src={url} alt={`Page ${i + 1}`} active={isPageActive(i)} cacheKey={{ galleryId, page: i }} />
        </div>
      ))}
    </div>
  );
}
