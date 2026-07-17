import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { fetchLlmSearchHistory, recordLlmSearchHistory } from '../api/llm-search';

export function useLlmSearchHistory(query: string, limit?: number) {
  return useQuery({
    queryKey: ['llmSearchHistory', query, limit ?? 'all'],
    queryFn: () => fetchLlmSearchHistory(query, limit),
    staleTime: 30 * 1000,
  });
}

export function useRecordLlmSearchHistory() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ query, topK, candidateK }: { query: string; topK: number; candidateK: number }) =>
      recordLlmSearchHistory(query, topK, candidateK),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['llmSearchHistory'] }),
  });
}
