import { useQuery, useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getHistory, insertReadLog, updateReadLog } from '../api/history';

export function useReadHistory(page = 0, pageSize = 30, enabled = true) {
  return useQuery({
    queryKey: ['readHistory', page, pageSize],
    queryFn: () => getHistory(page, pageSize),
    enabled,
  });
}

export function useInfiniteReadHistory(pageSize = 30, enabled = true) {
  return useInfiniteQuery({
    queryKey: ['readHistory-infinite', pageSize],
    queryFn: ({ pageParam = 0 }) => getHistory(pageParam, pageSize),
    initialPageParam: 0,
    getNextPageParam: (lastPage, allPages) => {
      const totalPages = Math.ceil(lastPage.totalCount / pageSize);
      return allPages.length < totalPages ? allPages.length : undefined;
    },
    enabled,
  });
}

export function useInsertReadLog() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: insertReadLog,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['readHistory'] });
    },
  });
}

export function useUpdateReadLog() {
  return useMutation({
    mutationFn: ({ id, ...req }: { id: number; LastPage: number; DateTimeEnd?: string }) =>
      updateReadLog(id, req),
  });
}
