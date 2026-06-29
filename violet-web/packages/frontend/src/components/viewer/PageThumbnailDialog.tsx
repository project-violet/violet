import { useEffect, useRef, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import styles from './PageThumbnailDialog.module.css';

interface PageThumbnailDialogProps {
  thumbnailUrls: string[];
  currentPage: number;
  totalPages: number;
  twoPageMode: boolean;
  coverPageMode: 'cover' | 'normal';
  onPageSelect: (page: number) => void;
  onClose: () => void;
}

export function PageThumbnailDialog({
  thumbnailUrls,
  currentPage,
  totalPages,
  twoPageMode,
  coverPageMode,
  onPageSelect,
  onClose,
}: PageThumbnailDialogProps) {
  const { t } = useTranslation();
  const activeRef = useRef<HTMLDivElement>(null);

  // Scroll to current page on mount
  useEffect(() => {
    if (activeRef.current) {
      activeRef.current.scrollIntoView({ block: 'center', behavior: 'instant' });
    }
  }, []);

  // Close on Escape
  useEffect(() => {
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.stopPropagation();
        onClose();
      }
    };
    window.addEventListener('keydown', handleKey);
    return () => window.removeEventListener('keydown', handleKey);
  }, [onClose]);

  const isPageActive = useCallback(
    (pageIndex: number): boolean => {
      if (!twoPageMode) {
        return pageIndex === currentPage;
      }
      // Two-page mode: highlight both visible pages
      if (coverPageMode === 'cover') {
        if (currentPage === 0) return pageIndex === 0;
        // Pages are paired: 1+2, 3+4, ...
        const pairStart = currentPage % 2 === 1 ? currentPage : currentPage - 1;
        return pageIndex === pairStart || pageIndex === pairStart + 1;
      } else {
        // Normal: 0+1, 2+3, 4+5, ...
        const pairStart = currentPage % 2 === 0 ? currentPage : currentPage - 1;
        return pageIndex === pairStart || pageIndex === pairStart + 1;
      }
    },
    [currentPage, twoPageMode, coverPageMode],
  );

  // Use first active page for scrollIntoView ref
  const firstActivePage = (() => {
    for (let i = 0; i < totalPages; i++) {
      if (isPageActive(i)) return i;
    }
    return currentPage;
  })();

  const handleSelect = (pageIndex: number) => {
    onPageSelect(pageIndex);
    onClose();
  };

  return (
    <div className={styles.overlay} onClick={onClose}>
      <div className={styles.dialog} onClick={(e) => e.stopPropagation()}>
        <div className={styles.header}>
          <span className={styles.title}>
            {t('viewer.pageInfo', { current: currentPage + 1, total: totalPages })}
          </span>
          <button className={styles.closeBtn} onClick={onClose}>
            ✕
          </button>
        </div>
        <div className={styles.grid}>
          {Array.from({ length: totalPages }, (_, i) => {
            const active = isPageActive(i);
            return (
              <div
                key={i}
                ref={i === firstActivePage ? activeRef : undefined}
                className={`${styles.item} ${active ? styles.active : ''}`}
                onClick={() => handleSelect(i)}
              >
                <img
                  className={styles.thumbnail}
                  src={thumbnailUrls[i]}
                  alt={`Page ${i + 1}`}
                  loading="lazy"
                />
                <span className={styles.pageNum}>{i + 1}</span>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
