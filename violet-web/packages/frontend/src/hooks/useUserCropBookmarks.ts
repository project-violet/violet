import { useQuery } from '@tanstack/react-query';
import type { BookmarkCropImage } from '@violet-web/shared';
import { api } from '../api/client';

interface RawCropBookmark {
  area: string;
  aspectRatio: number;
  article: number;
  page: number;
  datetime: string;
}

async function fetchUserCropBookmarks(): Promise<BookmarkCropImage[]> {
  const { data } = await api.get<RawCropBookmark[]>('/bookmarks/crops/user');

  return data.map((item, idx) => ({
    Id: -(idx + 1), // negative IDs to distinguish from server bookmarks
    Article: item.article,
    Page: item.page,
    Area: item.area,
    AspectRatio: item.aspectRatio,
    DateTime: item.datetime,
  }));
}

export function useUserCropBookmarks(enabled: boolean) {
  return useQuery({
    queryKey: ['userCropBookmarks'],
    queryFn: fetchUserCropBookmarks,
    enabled,
    staleTime: 10 * 60 * 1000,
  });
}
