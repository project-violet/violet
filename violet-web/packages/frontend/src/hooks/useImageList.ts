import { useQuery } from '@tanstack/react-query';
import { resolveGallery } from '../api/proxy';

export function useImageList(galleryId: number) {
  return useQuery({
    queryKey: ['imageList', galleryId],
    queryFn: () => resolveGallery(galleryId),
    enabled: galleryId > 0,
    staleTime: 30 * 60 * 1000,
  });
}
