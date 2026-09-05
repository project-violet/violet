import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router';
import type { Article } from '@violet-web/shared';

export function useResultGridKeyboard(articles: Article[], resetKey: string) {
  const navigate = useNavigate();
  const [selectedIndex, setSelectedIndex] = useState<number | null>(null);

  useEffect(() => {
    setSelectedIndex(null);
  }, [resetKey]);

  useEffect(() => {
    if (selectedIndex != null && selectedIndex >= articles.length) {
      setSelectedIndex(articles.length > 0 ? articles.length - 1 : null);
    }
  }, [articles.length, selectedIndex]);

  useEffect(() => {
    const handleResultKeyboard = (e: KeyboardEvent) => {
      if (articles.length === 0) return;

      const target = e.target as HTMLElement;
      const isSearchInput = target.matches('input[role="combobox"]');
      const searchDropdownOpen = isSearchInput && target.getAttribute('aria-expanded') === 'true';
      const isTypingTarget = target.tagName === 'TEXTAREA'
        || target.isContentEditable
        || (target.tagName === 'INPUT' && !isSearchInput);

      if (searchDropdownOpen || isTypingTarget || target.closest('[role="dialog"]')) return;

      if (e.key === 'Enter' && selectedIndex != null) {
        e.preventDefault();
        navigate(`/viewer/${articles[selectedIndex].Id}`);
        return;
      }

      const navigationKey = e.key.toLowerCase();
      if (!['w', 'a', 's', 'd'].includes(navigationKey)) return;

      e.preventDefault();
      e.stopPropagation();

      const grid = document.querySelector<HTMLElement>('[data-keyboard-result-grid="true"]');
      const columnCount = grid
        ? Math.max(1, getComputedStyle(grid).gridTemplateColumns.split(' ').length)
        : 1;

      setSelectedIndex((current) => {
        if (current == null) return 0;

        const offset = navigationKey === 'a'
          ? -1
          : navigationKey === 'd'
            ? 1
            : navigationKey === 'w'
              ? -columnCount
              : columnCount;

        return Math.min(articles.length - 1, Math.max(0, current + offset));
      });
    };

    window.addEventListener('keydown', handleResultKeyboard, { capture: true });
    return () => window.removeEventListener('keydown', handleResultKeyboard, { capture: true });
  }, [articles, navigate, selectedIndex]);

  return selectedIndex == null ? undefined : articles[selectedIndex]?.Id;
}
