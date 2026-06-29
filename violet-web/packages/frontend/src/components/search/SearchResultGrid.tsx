import { useTranslation } from 'react-i18next';
import type { Article } from '@violet-web/shared';
import { ArticleCard } from './ArticleCard';
import { useAppStore } from '../../stores/app-store';
import styles from './SearchResultGrid.module.css';

interface SearchResultGridProps {
  articles: Article[];
  rankInfo?: Map<number, { rank: number; viewCount: number }>;
}

export function SearchResultGrid({ articles, rankInfo }: SearchResultGridProps) {
  const { t } = useTranslation();
  const viewMode = useAppStore((s) => s.viewMode);
  const cardMinWidth = useAppStore((s) => s.cardMinWidth);

  if (articles.length === 0) {
    return <div className={styles.empty}>{t('search.noResults')}</div>;
  }

  return (
    <div
      className={styles.grid}
      style={{ '--card-min-width': `${cardMinWidth}px` } as React.CSSProperties}
    >
      {articles.map((article) => {
        const ri = rankInfo?.get(article.Id);
        return (
          <ArticleCard
            key={article.Id}
            article={article}
            viewMode={viewMode}
            rank={ri?.rank}
            viewCount={ri?.viewCount}
          />
        );
      })}
    </div>
  );
}
