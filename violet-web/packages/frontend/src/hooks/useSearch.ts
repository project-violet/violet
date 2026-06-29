import { useQuery, useInfiniteQuery } from '@tanstack/react-query';
import { searchArticles } from '../api/content';

export function useSearch(query: string, page: number, pageSize = 30) {
  return useQuery({
    queryKey: ['search', query, page, pageSize],
    queryFn: () => searchArticles(query, page, pageSize),
    enabled: query.length > 0,
  });
}

export function useInfiniteSearch(query: string, pageSize = 30) {
  return useInfiniteQuery({
    queryKey: ['search-infinite', query, pageSize],
    queryFn: ({ pageParam = 0 }) => searchArticles(query, pageParam, pageSize),
    initialPageParam: 0,
    getNextPageParam: (lastPage, allPages) => {
      const totalPages = Math.ceil(lastPage.totalCount / pageSize);
      return allPages.length < totalPages ? allPages.length : undefined;
    },
    enabled: query.length > 0,
  });
}
