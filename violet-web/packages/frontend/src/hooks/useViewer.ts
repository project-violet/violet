import { useState, useCallback, useEffect } from 'react';
import { useViewerStore } from '../stores/viewer-store';

export function useViewer(totalPages: number, initialPage: number = 0) {
  const [currentPage, setCurrentPage] = useState(() => {
    const clamped = Math.max(0, Math.min(initialPage, totalPages - 1));
    return clamped;
  });
  const { readDirection } = useViewerStore();

  const goToPage = useCallback(
    (page: number) => {
      const clamped = Math.max(0, Math.min(page, totalPages - 1));
      setCurrentPage(clamped);
    },
    [totalPages],
  );

  const nextPage = useCallback(() => {
    goToPage(currentPage + 1);
  }, [currentPage, goToPage]);

  const prevPage = useCallback(() => {
    goToPage(currentPage - 1);
  }, [currentPage, goToPage]);

  // Keyboard navigation
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'ArrowRight') {
        readDirection === 'rtl' ? prevPage() : nextPage();
      } else if (e.key === 'ArrowLeft') {
        readDirection === 'rtl' ? nextPage() : prevPage();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [nextPage, prevPage, readDirection]);

  return {
    currentPage,
    totalPages,
    goToPage,
    nextPage,
    prevPage,
    isFirst: currentPage === 0,
    isLast: currentPage >= totalPages - 1,
  };
}
