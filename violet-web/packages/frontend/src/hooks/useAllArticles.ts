import { useQuery } from '@tanstack/react-query';
import { getArticlesBatch } from '../api/content';
import type { Article } from '@violet-web/shared';

/**
 * Fetch all articles for a list of IDs using the batch API.
 * Returns the full article array once loaded.
 */
export function useAllArticles(
  queryKey: string,
  articleIds: string[] | undefined,
) {
  return useQuery<Article[]>({
    queryKey: [queryKey, 'all-articles', articleIds],
    queryFn: async () => {
      if (!articleIds || articleIds.length === 0) return [];
      const numericIds = articleIds.map((id) => parseInt(id));
      // Batch in chunks of 2000 to stay within limits
      const results: Article[] = [];
      for (let i = 0; i < numericIds.length; i += 2000) {
        const chunk = numericIds.slice(i, i + 2000);
        const articles = await getArticlesBatch(chunk);
        results.push(...articles);
      }
      return results;
    },
    enabled: !!articleIds && articleIds.length > 0,
    staleTime: 5 * 60 * 1000,
  });
}
