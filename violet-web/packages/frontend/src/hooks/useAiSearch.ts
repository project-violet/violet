import { useQuery } from '@tanstack/react-query';
import { aiSearch } from '../api/ai-search';
import { getArticle } from '../api/content';
import type { AiSearchResponse } from '@violet-web/shared';
import type { Article } from '@violet-web/shared';

export interface AiSearchResult {
  response: AiSearchResponse | undefined;
  articles: Article[];
  isLoading: boolean;
  isError: boolean;
  error: Error | null;
}

export function useAiSearch(query: string, topK = 5, mode = 'fast'): AiSearchResult {
  const {
    data: response,
    isLoading: isSearchLoading,
    isError: isSearchError,
    error: searchError,
  } = useQuery({
    queryKey: ['ai-search', query, topK, mode],
    queryFn: () => aiSearch(query, topK, mode),
    enabled: query.length > 0,
    staleTime: 5 * 60 * 1000,
  });

  const articleIds = response?.results.map((r) => r.articleId) ?? [];

  const {
    data: articles,
    isLoading: isArticlesLoading,
    isError: isArticlesError,
    error: articlesError,
  } = useQuery({
    queryKey: ['ai-search-articles', articleIds],
    queryFn: () => Promise.all(articleIds.map((id) => getArticle(Number(id)))),
    enabled: articleIds.length > 0,
    staleTime: 5 * 60 * 1000,
  });

  return {
    response,
    articles: articles ?? [],
    isLoading: isSearchLoading || (articleIds.length > 0 && isArticlesLoading),
    isError: isSearchError || isArticlesError,
    error: (searchError ?? articlesError) as Error | null,
  };
}
