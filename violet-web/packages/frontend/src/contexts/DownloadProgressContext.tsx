import { createContext, useContext } from 'react';
import type { DownloadRecord } from '@violet-web/shared';

const DownloadProgressContext = createContext<Map<string, DownloadRecord> | null>(null);

export const DownloadProgressProvider = DownloadProgressContext.Provider;

export function useDownloadProgress(articleId: string): DownloadRecord | undefined {
  const map = useContext(DownloadProgressContext);
  return map?.get(articleId);
}

export function useIsDownloadsPage(): boolean {
  return useContext(DownloadProgressContext) !== null;
}
