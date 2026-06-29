import { useQuery } from '@tanstack/react-query';
import { fetchSearchTagSummary } from '../api/content';
import type { TagChipData } from './useArticleTagSummary';

export function useSearchTagSummary(query: string, limit = 30) {
  return useQuery<TagChipData[]>({
    queryKey: ['search-tag-summary', query, limit],
    queryFn: () => fetchSearchTagSummary(query, limit),
    enabled: query.length > 0,
    staleTime: 60_000,
  });
}
