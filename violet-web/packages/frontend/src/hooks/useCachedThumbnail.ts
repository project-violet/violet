import { useState, useEffect, useCallback, useRef } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useAppStore } from '../stores/app-store';
import { getCachedImage, putCachedImage } from '../services/image-cache';
import { getThumbnailUrl, getProxyImageUrl } from '../api/proxy';

const THUMBNAIL_PAGE = -1;

const noop = () => {};

export function useCachedThumbnail(galleryId: number): { src: string; onLoadSuccess: () => void } {
  const imageCacheEnabled = useAppStore((s) => s.imageCacheEnabled);
  const imageCacheMaxSizeMB = useAppStore((s) => s.imageCacheMaxSizeMB);

  const { data: proxyUrl } = useQuery({
    queryKey: ['thumbnail', galleryId],
    queryFn: async () => {
      const url = await getThumbnailUrl(galleryId);
      return getProxyImageUrl(url, `https://hitomi.la/reader/${galleryId}.html`);
    },
    staleTime: 30 * 60 * 1000,
  });

  const [blobUrl, setBlobUrl] = useState<string | null>(null);
  const [cacheChecked, setCacheChecked] = useState(false);
  const blobUrlRef = useRef<string | null>(null);
  const savingRef = useRef(false);

  const enabled = imageCacheEnabled && !!proxyUrl;

  useEffect(() => {
    if (!enabled) {
      setCacheChecked(true);
      return;
    }

    let cancelled = false;
    setCacheChecked(false);
    setBlobUrl(null);

    getCachedImage(galleryId, THUMBNAIL_PAGE)
      .then((cached) => {
        if (cancelled) return;
        if (cached) {
          const url = URL.createObjectURL(cached.blob);
          blobUrlRef.current = url;
          setBlobUrl(url);
        }
        setCacheChecked(true);
      })
      .catch(() => {
        if (!cancelled) setCacheChecked(true);
      });

    return () => {
      cancelled = true;
      if (blobUrlRef.current) {
        URL.revokeObjectURL(blobUrlRef.current);
        blobUrlRef.current = null;
      }
      setBlobUrl(null);
    };
  }, [enabled, galleryId]);

  const onLoadSuccess = useCallback(() => {
    if (!enabled || blobUrl !== null || savingRef.current || !proxyUrl) return;
    savingRef.current = true;

    fetch(proxyUrl)
      .then((res) => {
        if (!res.ok) throw new Error('fetch failed');
        const contentType = res.headers.get('content-type') || 'image/jpeg';
        return res.blob().then((blob) => ({ blob, contentType }));
      })
      .then(({ blob, contentType }) => {
        const maxBytes = imageCacheMaxSizeMB * 1024 * 1024;
        return putCachedImage(galleryId, THUMBNAIL_PAGE, blob, contentType, maxBytes);
      })
      .catch(() => {})
      .finally(() => {
        savingRef.current = false;
      });
  }, [enabled, blobUrl, proxyUrl, galleryId, imageCacheMaxSizeMB]);

  if (!imageCacheEnabled) {
    return { src: proxyUrl ?? '', onLoadSuccess: noop };
  }

  if (!cacheChecked) {
    return { src: '', onLoadSuccess: noop };
  }

  return {
    src: blobUrl ?? proxyUrl ?? '',
    onLoadSuccess: blobUrl ? noop : onLoadSuccess,
  };
}
