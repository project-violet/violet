import { useState, useCallback, useEffect, useRef } from 'react';
import { useViewerStore } from '../stores/viewer-store';

export function useViewer(totalPages: number, initialPage: number = 0) {
  // The image list is loaded asynchronously, so totalPages is initially zero.
  // Preserve the URL page until the real page count is available.
  const [currentPage, setCurrentPage] = useState(() => Math.max(0, initialPage));
  const previousInitialPage = useRef(initialPage);
  const { readDirection } = useViewerStore();

  useEffect(() => {
    if (totalPages <= 0) return;

    setCurrentPage((page) => Math.max(0, Math.min(page, totalPages - 1)));
  }, [totalPages]);

  useEffect(() => {
    if (previousInitialPage.current === initialPage) return;

    previousInitialPage.current = initialPage;
    setCurrentPage(
      totalPages > 0
        ? Math.max(0, Math.min(initialPage, totalPages - 1))
        : Math.max(0, initialPage),
    );
  }, [initialPage, totalPages]);

  const goToPage = useCallback(
    (page: number) => {
      if (totalPages <= 0) return;
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
