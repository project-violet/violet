import { useState, useEffect, useCallback, useRef } from 'react';
import { useAppStore } from '../stores/app-store';
import { getCachedImage, putCachedImage } from '../services/image-cache';

const noop = () => {};

export function useCachedImage(
  proxyUrl: string,
  cacheKey: { galleryId: number; page: number } | null,
): { src: string; onLoadSuccess: () => void } {
  const imageCacheEnabled = useAppStore((s) => s.imageCacheEnabled);
  const imageCacheMaxSizeMB = useAppStore((s) => s.imageCacheMaxSizeMB);
  const [blobUrl, setBlobUrl] = useState<string | null>(null);
  const [cacheChecked, setCacheChecked] = useState(false);
  const blobUrlRef = useRef<string | null>(null);
  const savingRef = useRef(false);

  const enabled = imageCacheEnabled && cacheKey !== null;
  const galleryId = cacheKey?.galleryId ?? 0;
  const page = cacheKey?.page ?? 0;

  // Check cache on mount / when key changes
  useEffect(() => {
    if (!enabled) {
      setCacheChecked(true);
      return;
    }

    let cancelled = false;
    setCacheChecked(false);
    setBlobUrl(null);

    getCachedImage(galleryId, page)
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
  }, [enabled, galleryId, page]);

  const onLoadSuccess = useCallback(() => {
    if (!enabled || blobUrl !== null || savingRef.current) return;
    savingRef.current = true;

    fetch(proxyUrl)
      .then((res) => {
        if (!res.ok) throw new Error('fetch failed');
        const contentType = res.headers.get('content-type') || 'image/jpeg';
        return res.blob().then((blob) => ({ blob, contentType }));
      })
      .then(({ blob, contentType }) => {
        const maxBytes = imageCacheMaxSizeMB * 1024 * 1024;
        return putCachedImage(galleryId, page, blob, contentType, maxBytes);
      })
      .catch(() => {})
      .finally(() => {
        savingRef.current = false;
      });
  }, [enabled, blobUrl, proxyUrl, galleryId, page, imageCacheMaxSizeMB]);

  if (!enabled) {
    return { src: proxyUrl, onLoadSuccess: noop };
  }

  // Wait for cache check to prevent proxy→blob URL switch (double decode)
  if (!cacheChecked) {
    return { src: '', onLoadSuccess: noop };
  }

  return {
    src: blobUrl ?? proxyUrl,
    onLoadSuccess: blobUrl ? noop : onLoadSuccess,
  };
}
