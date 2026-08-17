import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router';
import type { BookmarkCropImage } from '@violet-web/shared';

export function getCropKeyboardKey(crop: BookmarkCropImage): string {
  return `${crop.Id}:${crop.Article}:${crop.Page}:${crop.Area}`;
}

export function useMasonryCropKeyboard(crops: BookmarkCropImage[], resetKey: string) {
  const navigate = useNavigate();
  const [selectedKey, setSelectedKey] = useState<string | null>(null);

  useEffect(() => {
    setSelectedKey(null);
  }, [resetKey]);

  useEffect(() => {
    if (selectedKey && !crops.some((crop) => getCropKeyboardKey(crop) === selectedKey)) {
      setSelectedKey(null);
    }
  }, [crops, selectedKey]);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (crops.length === 0) return;

      const target = e.target as HTMLElement;
      const isSearchInput = target.matches('input[role="combobox"]');
      const searchDropdownOpen = isSearchInput && target.getAttribute('aria-expanded') === 'true';
      const isTypingTarget = target.tagName === 'TEXTAREA'
        || target.isContentEditable
        || (target.tagName === 'INPUT' && !isSearchInput);

      if (searchDropdownOpen || isTypingTarget || target.closest('[role="dialog"]')) return;

      if (e.key === 'Enter' && selectedKey) {
        const crop = crops.find((item) => getCropKeyboardKey(item) === selectedKey);
        if (crop) {
          e.preventDefault();
          navigate(`/viewer/${crop.Article}?p=${crop.Page}`);
        }
        return;
      }

      const direction = e.key.toLowerCase();
      if (!['w', 'a', 's', 'd'].includes(direction)) return;

      e.preventDefault();
      e.stopPropagation();

      const cards = Array.from(
        document.querySelectorAll<HTMLElement>('[data-masonry-crop-card="true"]'),
      );
      if (cards.length === 0) return;

      if (!selectedKey) {
        const firstCard = cards
          .map((element) => ({ element, rect: element.getBoundingClientRect() }))
          .sort((a, b) => a.rect.top - b.rect.top || a.rect.left - b.rect.left)[0].element;
        setSelectedKey(firstCard.dataset.cropKeyboardKey ?? null);
        return;
      }

      const current = cards.find((card) => card.dataset.cropKeyboardKey === selectedKey);
      if (!current) {
        setSelectedKey(cards[0].dataset.cropKeyboardKey ?? null);
        return;
      }

      const currentRect = current.getBoundingClientRect();
      const currentX = currentRect.left + currentRect.width / 2;
      const currentY = currentRect.top + currentRect.height / 2;

      const candidates = cards.flatMap((card) => {
        if (card === current) return [];

        const rect = card.getBoundingClientRect();
        const x = rect.left + rect.width / 2;
        const y = rect.top + rect.height / 2;
        const dx = x - currentX;
        const dy = y - currentY;
        const inDirection = direction === 'a'
          ? dx < 0
          : direction === 'd'
            ? dx > 0
            : direction === 'w'
              ? dy < 0
              : dy > 0;

        if (!inDirection) return [];

        const primaryDistance = direction === 'a' || direction === 'd'
          ? Math.abs(dx)
          : Math.abs(dy);
        const crossDistance = direction === 'a' || direction === 'd'
          ? Math.abs(dy)
          : Math.abs(dx);

        return [{ card, score: primaryDistance + crossDistance * 2 }];
      });

      candidates.sort((a, b) => a.score - b.score);
      if (candidates[0]) {
        setSelectedKey(candidates[0].card.dataset.cropKeyboardKey ?? null);
      }
    };

    window.addEventListener('keydown', handleKeyDown, { capture: true });
    return () => window.removeEventListener('keydown', handleKeyDown, { capture: true });
  }, [crops, navigate, selectedKey]);

  return selectedKey;
}
