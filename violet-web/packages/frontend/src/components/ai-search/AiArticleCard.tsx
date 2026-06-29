import type { Article, AiSearchResultItem } from '@violet-web/shared';
import { ArticleCard } from '../search/ArticleCard';
import { useAppStore } from '../../stores/app-store';

interface AiArticleCardProps {
  article: Article;
  result: AiSearchResultItem;
}

export function AiArticleCard({ article, result }: AiArticleCardProps) {
  const viewMode = useAppStore((s) => s.viewMode);

  return (
    <ArticleCard
      article={article}
      viewMode={viewMode}
      aiScore={result.score}
      aiDescription={result.description}
    />
  );
}
