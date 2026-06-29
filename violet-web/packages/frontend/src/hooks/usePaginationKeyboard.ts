import { useEffect } from 'react';

/**
 * Adds Left/Right arrow key navigation for pagination.
 * Skips when focus is on an input/textarea or when scrollMode is not 'pagination'.
 */
export function usePaginationKeyboard(
  page: number,
  totalPages: number,
  setPage: (updater: number | ((prev: number) => number)) => void,
  enabled: boolean,
) {
  useEffect(() => {
    if (!enabled || totalPages <= 1) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement;
      if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA') return;

      if (e.key === 'ArrowLeft' && page > 0) {
        e.preventDefault();
        setPage((p) => p - 1);
      } else if (e.key === 'ArrowRight' && page < totalPages - 1) {
        e.preventDefault();
        setPage((p) => p + 1);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [page, totalPages, setPage, enabled]);
}
