import { useQuery } from '@tanstack/react-query';
import type { MessageSearchMode } from '@violet-web/shared';
import { messageSearch } from '../api/message-search';

export function useMessageSearch(
  query: string,
  mode: MessageSearchMode,
  limit: number,
  baseUrl: string,
) {
  return useQuery({
    queryKey: ['messageSearch', query, mode, limit, baseUrl],
    queryFn: () => messageSearch(query, mode, limit, baseUrl),
    enabled: query.trim().length > 0,
    staleTime: 5 * 60 * 1000,
    retry: 1,
  });
}
