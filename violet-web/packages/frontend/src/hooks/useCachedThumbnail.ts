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

  // Include the article ID so a recycled card never displays the previous blob.
  const [local, setLocal] = useState<{ galleryId: number; src: string | null } | null>(null);
  const savingRef = useRef<string | null>(null);
  const cacheChecked = !imageCacheEnabled || local?.galleryId === galleryId;
  const blobUrl = imageCacheEnabled && local?.galleryId === galleryId ? local.src : null;

  const { data: proxyUrl } = useQuery({
    queryKey: ['thumbnail', galleryId],
    queryFn: async () => {
      const url = await getThumbnailUrl(galleryId);
      return getProxyImageUrl(url, `https://hitomi.la/reader/${galleryId}.html`);
    },
    // An IndexedDB hit can be displayed without resolving a remote gallery at all.
    enabled: cacheChecked && !blobUrl,
    staleTime: 30 * 60 * 1000,
  });

  useEffect(() => {
    if (!imageCacheEnabled) {
      setLocal(null);
      return;
    }
    let cancelled = false;
    let objectUrl: string | null = null;
    setLocal(null);
    getCachedImage(galleryId, THUMBNAIL_PAGE)
      .then((cached) => {
        if (cancelled) return;
        objectUrl = cached ? URL.createObjectURL(cached.blob) : null;
        setLocal({ galleryId, src: objectUrl });
      })
      .catch(() => {
        if (!cancelled) setLocal({ galleryId, src: null });
      });
    return () => {
      cancelled = true;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [imageCacheEnabled, galleryId]);

  const onLoadSuccess = useCallback(() => {
    if (!imageCacheEnabled || blobUrl !== null || !proxyUrl) return;
    const saveKey = `${galleryId}:${proxyUrl}`;
    if (savingRef.current === saveKey) return;
    savingRef.current = saveKey;

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
        if (savingRef.current === saveKey) savingRef.current = null;
      });
  }, [imageCacheEnabled, blobUrl, proxyUrl, galleryId, imageCacheMaxSizeMB]);

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
