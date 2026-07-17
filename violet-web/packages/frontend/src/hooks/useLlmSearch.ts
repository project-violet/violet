import { useQuery } from '@tanstack/react-query';
import { llmSearch } from '../api/llm-search';

export function useLlmSearch(
  query: string,
  topK: number,
  candidateK: number,
  baseUrl: string,
) {
  return useQuery({
    queryKey: ['llmSearch', query, topK, candidateK, baseUrl],
    queryFn: () => llmSearch(query, topK, candidateK, baseUrl),
    enabled: query.trim().length > 0,
    staleTime: 5 * 60 * 1000,
    retry: 1,
  });
}
