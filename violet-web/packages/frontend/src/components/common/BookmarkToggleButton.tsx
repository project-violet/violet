import type { MouseEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { useIsBookmarked, useToggleBookmark } from '../../hooks/useBookmarks';
import styles from './BookmarkToggleButton.module.css';

interface BookmarkToggleButtonProps {
  articleId: number | string;
}

export function BookmarkToggleButton({ articleId }: BookmarkToggleButtonProps) {
  const { t } = useTranslation();
  const normalizedArticleId = String(articleId);
  const { data: isBookmarked } = useIsBookmarked(normalizedArticleId);
  const toggleBookmark = useToggleBookmark();

  const handleClick = (event: MouseEvent<HTMLButtonElement>) => {
    event.stopPropagation();
    toggleBookmark.mutate({
      articleId: normalizedArticleId,
      isBookmarked: !!isBookmarked,
    });
  };

  return (
    <button
      type="button"
      className={`${styles.button} ${isBookmarked ? styles.bookmarked : ''}`}
      onClick={handleClick}
      disabled={toggleBookmark.isPending}
      aria-label={isBookmarked ? t('article.bookmarked') : t('article.bookmark')}
    >
      {isBookmarked ? '★' : '☆'}
    </button>
  );
}
