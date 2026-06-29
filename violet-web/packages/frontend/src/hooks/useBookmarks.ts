import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import {
  getGroups,
  getBookmarkArticles,
  addBookmarkArticle,
  deleteBookmarkArticle,
  checkBookmark,
  getCropBookmarks,
  addCropBookmark,
  deleteCropBookmark,
} from '../api/bookmarks';
import { useToastStore } from '../stores/toast-store';

export function useBookmarkGroups() {
  return useQuery({
    queryKey: ['bookmarkGroups'],
    queryFn: getGroups,
  });
}

export function useBookmarkArticles(groupId?: number) {
  return useQuery({
    queryKey: ['bookmarkArticles', groupId],
    queryFn: () => getBookmarkArticles(groupId),
  });
}

export function useIsBookmarked(articleId: string) {
  return useQuery({
    queryKey: ['isBookmarked', articleId],
    queryFn: () => checkBookmark(articleId),
    enabled: !!articleId,
  });
}

export function useAddBookmark() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: addBookmarkArticle,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['bookmarkArticles'] });
      qc.invalidateQueries({ queryKey: ['isBookmarked'] });
    },
  });
}

export function useRemoveBookmark() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: deleteBookmarkArticle,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['bookmarkArticles'] });
      qc.invalidateQueries({ queryKey: ['isBookmarked'] });
    },
  });
}

export function useCropBookmarks() {
  return useQuery({
    queryKey: ['cropBookmarks'],
    queryFn: getCropBookmarks,
  });
}

export function useAddCropBookmark() {
  const qc = useQueryClient();
  const addToast = useToastStore((state) => state.addToast);
  const { t } = useTranslation();
  return useMutation({
    mutationFn: addCropBookmark,
    onSuccess: (_data, variables) => {
      qc.invalidateQueries({ queryKey: ['cropBookmarks'] });
      addToast(t('crop.savedToast', { page: variables.Page + 1 }), 'success');
    },
    onError: () => {
      addToast(t('crop.saveErrorToast'), 'error');
    },
  });
}

export function useDeleteCropBookmark() {
  const qc = useQueryClient();
  const addToast = useToastStore((state) => state.addToast);
  const { t } = useTranslation();
  return useMutation({
    mutationFn: deleteCropBookmark,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['cropBookmarks'] });
      addToast(t('crop.deletedToast'), 'info');
    },
    onError: () => {
      addToast(t('crop.deleteErrorToast'), 'error');
    },
  });
}

const VIOLET_DEFAULT_GROUP_ID = 1;

export function useToggleBookmark() {
  const qc = useQueryClient();
  const addToast = useToastStore((state) => state.addToast);
  const { t } = useTranslation();

  return useMutation({
    mutationFn: async ({ articleId, isBookmarked }: { articleId: string; isBookmarked: boolean }) => {
      if (isBookmarked) {
        // Find bookmark ID from the bookmarks list
        const bookmarks = await getBookmarkArticles();
        const bookmark = bookmarks.find((b) => b.Article === articleId);
        if (bookmark) {
          await deleteBookmarkArticle(bookmark.Id);
          return { action: 'removed' as const };
        }
        throw new Error('Bookmark not found');
      } else {
        await addBookmarkArticle({ Article: articleId, GroupId: VIOLET_DEFAULT_GROUP_ID });
        return { action: 'added' as const };
      }
    },
    onSuccess: (data) => {
      qc.invalidateQueries({ queryKey: ['bookmarkArticles'] });
      qc.invalidateQueries({ queryKey: ['isBookmarked'] });

      if (data.action === 'added') {
        addToast(t('bookmark.addedToast'), 'success');
      } else {
        addToast(t('bookmark.removedToast'), 'info');
      }
    },
    onError: () => {
      addToast(t('bookmark.errorToast'), 'error');
    },
  });
}
