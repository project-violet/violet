import { useQuery } from '@tanstack/react-query';
import { fetchSearchTagSummary } from '../api/content';
import type { TagChipData } from './useArticleTagSummary';

interface SearchTagSummaryOptions {
  enabled?: boolean;
}

export function useSearchTagSummary(
  query: string,
  limit = 30,
  options: SearchTagSummaryOptions = {},
) {
  return useQuery<TagChipData[]>({
    queryKey: ['search-tag-summary', query, limit],
    queryFn: () => fetchSearchTagSummary(query, limit),
    enabled: query.length > 0 && options.enabled !== false,
    staleTime: 60_000,
  });
}
