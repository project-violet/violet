import { useQuery } from '@tanstack/react-query';
import type { MessageSearchMode, MessageSearchFilters } from '@violet-web/shared';
import { messageSearch, scopedMessageSearch } from '../api/message-search';

export function useMessageSearch(
  query: string,
  mode: MessageSearchMode,
  limit: number,
  baseUrl: string,
  filters: MessageSearchFilters = {},
  articleIds?: number[],
  enabled = true,
) {
  return useQuery({
    queryKey: ['messageSearch', query, mode, limit, baseUrl, filters, articleIds],
    queryFn: ({ signal }) => articleIds === undefined
      ? messageSearch(query, mode, limit, baseUrl, undefined, filters)
      : scopedMessageSearch(query, mode, articleIds, limit, baseUrl, signal),
    enabled: enabled && query.trim().length > 0 && articleIds?.length !== 0,
    staleTime: 5 * 60 * 1000,
    retry: 1,
  });
}
