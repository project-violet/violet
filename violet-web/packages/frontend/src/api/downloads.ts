import type { DownloadRecord } from '@violet-web/shared';
import { api } from './client';

export interface DownloadsResponse {
  downloads: DownloadRecord[];
  totalCount: number;
  page: number;
  pageSize: number;
}

export async function getDownloads(page = 0, pageSize = 30): Promise<DownloadsResponse> {
  const { data } = await api.get<DownloadsResponse>('/downloads', {
    params: { page, pageSize },
  });
  return data;
}

export async function getDownloadIds(): Promise<string[]> {
  const { data } = await api.get<{ articleIds: string[] }>('/downloads/ids');
  return data.articleIds;
}

export async function getDownload(id: number): Promise<DownloadRecord> {
  const { data } = await api.get<DownloadRecord>(`/downloads/${id}`);
  return data;
}

export async function createDownload(articleId: string): Promise<DownloadRecord> {
  const { data } = await api.post<DownloadRecord>('/downloads', { articleId });
  return data;
}

export async function retryDownload(id: number): Promise<DownloadRecord> {
  const { data } = await api.post<DownloadRecord>(`/downloads/${id}/retry`);
  return data;
}

export async function deleteDownload(id: number): Promise<void> {
  await api.delete(`/downloads/${id}`);
}

export async function checkDownloaded(articleId: string): Promise<boolean> {
  const { data } = await api.get<{ downloaded: boolean }>(
    `/downloads/check/${articleId}`,
  );
  return data.downloaded;
}
