import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { fetchMessageSearchHistory, recordMessageSearchHistory } from '../api/message-search';

export function useMessageSearchHistory(query: string, limit?: number) {
  return useQuery({
    queryKey: ['messageSearchHistory', query, limit ?? 'all'],
    queryFn: () => fetchMessageSearchHistory(query, limit),
    staleTime: 30 * 1000,
  });
}

export function useRecordMessageSearchHistory() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: recordMessageSearchHistory,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['messageSearchHistory'] });
    },
  });
}
