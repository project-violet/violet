import { api } from './client';

export interface SyncProgress {
  status: 'idle' | 'checking' | 'downloading_full' | 'applying_chunks' | 'building_cache' | 'error';
  lastSync: string | null;
  lastSyncDb: string | null;
  dbExists: boolean;
  error: string | null;
  progress?: {
    current: number;
    total: number;
    message: string;
  };
}

export async function getSyncStatus(): Promise<SyncProgress> {
  const { data } = await api.get<SyncProgress>('/sync/status');
  return data;
}

export async function triggerSync(): Promise<{ message: string }> {
  const { data } = await api.post<{ message: string }>('/sync/trigger');
  return data;
}

export async function triggerFullSync(): Promise<{ message: string }> {
  const { data } = await api.post<{ message: string }>('/sync/full');
  return data;
}
