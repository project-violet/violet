import { useQuery, useInfiniteQuery } from '@tanstack/react-query';
import { searchArticles } from '../api/content';
import type { SearchDateRange } from '@violet-web/shared';

interface SearchQueryOptions {
  enabled?: boolean;
  dateRange?: SearchDateRange;
}

export function useSearch(
  query: string,
  page: number,
  pageSize = 30,
  options: SearchQueryOptions = {},
) {
  return useQuery({
    queryKey: ['search', query, page, pageSize, options.dateRange?.from, options.dateRange?.to],
    queryFn: () => searchArticles(query, page, pageSize, options.dateRange),
    enabled: query.length > 0 && options.enabled !== false,
  });
}

export function useInfiniteSearch(
  query: string,
  pageSize = 30,
  options: SearchQueryOptions = {},
) {
  return useInfiniteQuery({
    queryKey: ['search-infinite', query, pageSize, options.dateRange?.from, options.dateRange?.to],
    queryFn: ({ pageParam = 0 }) => searchArticles(query, pageParam, pageSize, options.dateRange),
    initialPageParam: 0,
    getNextPageParam: (lastPage, allPages) => {
      const totalPages = Math.ceil(lastPage.totalCount / pageSize);
      return allPages.length < totalPages ? allPages.length : undefined;
    },
    enabled: query.length > 0 && options.enabled !== false,
  });
}
