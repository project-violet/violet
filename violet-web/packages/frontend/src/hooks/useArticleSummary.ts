import { useQuery } from '@tanstack/react-query';
import { getArticleSummary } from '../api/summary';

export function useArticleSummary(articleId: number) {
  return useQuery({
    queryKey: ['summary', articleId],
    queryFn: () => getArticleSummary(articleId),
    staleTime: 30 * 60 * 1000,
  });
}
