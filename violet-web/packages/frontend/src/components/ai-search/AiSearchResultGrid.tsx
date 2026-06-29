import { useTranslation } from 'react-i18next';
import type { Article, AiSearchResultItem } from '@violet-web/shared';
import { AiArticleCard } from './AiArticleCard';
import { useAppStore } from '../../stores/app-store';
import gridStyles from '../search/SearchResultGrid.module.css';

interface AiSearchResultGridProps {
  articles: Article[];
  results: AiSearchResultItem[];
}

export function AiSearchResultGrid({ articles, results }: AiSearchResultGridProps) {
  const { t } = useTranslation();
  const cardMinWidth = useAppStore((s) => s.cardMinWidth);

  const articleMap = new Map(articles.map((a) => [String(a.Id), a]));

  const sortedResults = [...results].sort((a, b) => b.score - a.score);

  const items = sortedResults
    .map((result) => {
      const article = articleMap.get(result.articleId);
      return article ? { article, result } : null;
    })
    .filter((item): item is { article: Article; result: AiSearchResultItem } => item !== null);

  if (items.length === 0) {
    return <div className={gridStyles.empty}>{t('aiSearch.noResults')}</div>;
  }

  return (
    <div
      className={gridStyles.grid}
      style={{ '--card-min-width': `${cardMinWidth}px` } as React.CSSProperties}
    >
      {items.map((item) => (
        <AiArticleCard
          key={item.result.articleId}
          article={item.article}
          result={item.result}
        />
      ))}
    </div>
  );
}
