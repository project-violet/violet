import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getSuggestionCacheStatus, rebuildSuggestionCache } from '../api/content';

export function useSuggestionCacheStatus() {
  return useQuery({
    queryKey: ['suggestion-cache', 'status'],
    queryFn: getSuggestionCacheStatus,
    refetchInterval: 30000, // Refetch every 30 seconds
  });
}

export function useRebuildSuggestionCache() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: rebuildSuggestionCache,
    onSuccess: () => {
      // Invalidate status to trigger immediate refetch
      queryClient.invalidateQueries({ queryKey: ['suggestion-cache', 'status'] });
      // Also invalidate any existing suggestions
      queryClient.invalidateQueries({ queryKey: ['suggestions'] });
    },
  });
}
