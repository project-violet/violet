import { useMemo } from 'react';
import { useSearchParams } from 'react-router';
import type { Article } from '@violet-web/shared';
import { filterLocalArticles } from './local-article-search';

/** Filter local articles using the URL search query. */
export function useLocalArticleSearch(articles: Article[]): Article[] {
  const [searchParams] = useSearchParams();
  const query = searchParams.get('q') || '';

  return useMemo(() => filterLocalArticles(articles, query), [articles, query]);
}
