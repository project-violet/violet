import { useQuery, useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { getDownloads, createDownload, retryDownload, deleteDownload, checkDownloaded } from '../api/downloads';
import { useToastStore } from '../stores/toast-store';

export function useDownloadHistory(page = 0, pageSize = 30, enabled = true) {
  return useQuery({
    queryKey: ['downloads', page, pageSize],
    queryFn: () => getDownloads(page, pageSize),
    enabled,
    refetchInterval: (query) => {
      const downloads = query.state.data?.downloads;
      if (downloads?.some((dl) => dl.Status === 'downloading')) {
        return 2000;
      }
      return false;
    },
  });
}

export function useInfiniteDownloadHistory(pageSize = 30, enabled = true) {
  return useInfiniteQuery({
    queryKey: ['downloads-infinite', pageSize],
    queryFn: ({ pageParam = 0 }) => getDownloads(pageParam, pageSize),
    initialPageParam: 0,
    getNextPageParam: (lastPage, allPages) => {
      const totalPages = Math.ceil(lastPage.totalCount / pageSize);
      return allPages.length < totalPages ? allPages.length : undefined;
    },
    enabled,
    refetchInterval: (query) => {
      const pages = query.state.data?.pages;
      if (pages?.some((p) => p.downloads.some((dl) => dl.Status === 'downloading'))) {
        return 2000;
      }
      return false;
    },
  });
}

export function useIsDownloaded(articleId: string) {
  return useQuery({
    queryKey: ['downloaded', articleId],
    queryFn: () => checkDownloaded(articleId),
    staleTime: 5 * 60 * 1000,
  });
}

export function useStartDownload() {
  const qc = useQueryClient();
  const { t } = useTranslation();
  const addToast = useToastStore((s) => s.addToast);

  return useMutation({
    mutationFn: async (articleId: string) => {
      const already = await checkDownloaded(articleId);
      if (already) {
        throw new Error('already_downloaded');
      }
      return createDownload(articleId);
    },
    onSuccess: () => {
      addToast(t('downloads.startToast'), 'info');
      qc.invalidateQueries({ queryKey: ['downloads'] });
      qc.invalidateQueries({ queryKey: ['downloads-infinite'] });
    },
    onError: (_err) => {
      if (_err instanceof Error && _err.message === 'already_downloaded') {
        addToast(t('downloads.alreadyToast'), 'info');
      } else {
        addToast(t('downloads.errorToast'), 'error');
      }
    },
  });
}

export function useRetryDownload() {
  const qc = useQueryClient();

  return useMutation({
    mutationFn: (id: number) => retryDownload(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['downloads'] });
      qc.invalidateQueries({ queryKey: ['downloads-infinite'] });
    },
  });
}

export function useDeleteDownload() {
  const qc = useQueryClient();

  return useMutation({
    mutationFn: (id: number) => deleteDownload(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['downloads'] });
      qc.invalidateQueries({ queryKey: ['downloads-infinite'] });
    },
  });
}
