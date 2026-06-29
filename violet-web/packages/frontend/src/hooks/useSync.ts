import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getSyncStatus, triggerSync, triggerFullSync } from '../api/sync';

export function useSyncStatus() {
  const query = useQuery({
    queryKey: ['sync', 'status'],
    queryFn: getSyncStatus,
    refetchInterval: (query) => {
      // Poll every 2 seconds when syncing, every 30 seconds when idle
      const status = query.state.data?.status;
      if (
        status === 'checking' ||
        status === 'downloading_full' ||
        status === 'applying_chunks' ||
        status === 'building_cache'
      ) {
        return 2000;
      }
      return 30000;
    },
  });

  return query;
}

export function useTriggerSync() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: triggerSync,
    onSuccess: () => {
      // Invalidate status to trigger immediate refetch
      queryClient.invalidateQueries({ queryKey: ['sync', 'status'] });
    },
  });
}

export function useTriggerFullSync() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: triggerFullSync,
    onSuccess: () => {
      // Invalidate status to trigger immediate refetch
      queryClient.invalidateQueries({ queryKey: ['sync', 'status'] });
    },
  });
}
