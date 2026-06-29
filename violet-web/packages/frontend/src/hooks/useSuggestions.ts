import { useQuery } from '@tanstack/react-query';
import { fetchSuggestions } from '../api/content';

/**
 * Extract the last token from search input
 */
function getLastToken(input: string): string {
  const tokens = input.trim().split(/\s+/);
  return tokens[tokens.length - 1] || '';
}

/**
 * Hook to fetch suggestions based on search input
 * No debouncing - queries immediately (local API + in-memory cache is fast)
 */
export function useSuggestions(input: string, limit = 20) {
  const lastToken = getLastToken(input);

  return useQuery({
    queryKey: ['suggestions', lastToken, limit],
    queryFn: () => fetchSuggestions(lastToken, limit),
    enabled: lastToken.length > 0,
    staleTime: 60000, // 60 seconds
  });
}
