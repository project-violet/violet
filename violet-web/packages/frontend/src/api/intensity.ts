import type { IntensityTimeline, IntensityTimelineStatus } from '@violet-web/shared';
import { api } from './client';

export async function getIntensityTimeline(workId: number): Promise<IntensityTimeline> {
  const { data } = await api.get<IntensityTimeline>(`/intensity/${workId}`);
  return data;
}

export async function getIntensityTimelineStatus(): Promise<IntensityTimelineStatus> {
  const { data } = await api.get<IntensityTimelineStatus>('/intensity/status');
  return data;
}
