import { useQuery } from '@tanstack/react-query';
import { getThumbnailUrl, getProxyImageUrl } from '../api/proxy';

export function useThumbnail(galleryId: number) {
  return useQuery({
    queryKey: ['thumbnail', galleryId],
    queryFn: async () => {
      const url = await getThumbnailUrl(galleryId);
      // Return proxied URL with referer
      return getProxyImageUrl(url, `https://hitomi.la/reader/${galleryId}.html`);
    },
    staleTime: 30 * 60 * 1000, // 30 minutes (matches backend cache)
  });
}
