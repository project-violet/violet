import { useQuery } from '@tanstack/react-query';
import type { MessageSearchMode, MessageSearchFilters } from '@violet-web/shared';
import { messageSearch } from '../api/message-search';

export function useMessageSearch(
  query: string,
  mode: MessageSearchMode,
  limit: number,
  baseUrl: string,
  filters: MessageSearchFilters = {},
) {
  return useQuery({
    queryKey: ['messageSearch', query, mode, limit, baseUrl, filters],
    queryFn: () => messageSearch(query, mode, limit, baseUrl, undefined, filters),
    enabled: query.trim().length > 0,
    staleTime: 5 * 60 * 1000,
    retry: 1,
  });
}
