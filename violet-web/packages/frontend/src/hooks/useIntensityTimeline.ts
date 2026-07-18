import { useQuery } from '@tanstack/react-query';
import { getIntensityTimeline } from '../api/intensity';

export function useIntensityTimeline(workId: number) {
  return useQuery({
    queryKey: ['intensityTimeline', workId],
    queryFn: () => getIntensityTimeline(workId),
    enabled: workId > 0,
    staleTime: Infinity,
    retry: false,
  });
}
