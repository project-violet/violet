import { useMemo, useEffect, useRef, useState } from 'react';
import type { BookmarkCropImage } from '@violet-web/shared';
import { CropImageCard } from './CropImageCard';
import { useColumnCount } from '../../hooks/useColumnCount';
import { useAppStore } from '../../stores/app-store';
import {
  getCachedImagesBulk,
  getCropThumbnailsBulk,
  putCropThumbnail,
} from '../../services/image-cache';
import styles from './CropBookmarkGrid.module.css';

interface CropBookmarkGridProps {
  crops: BookmarkCropImage[];
  columnWidth: number;
  onDelete: (id: number) => void;
}

function parseCropArea(area: string) {
  const [left, top, right, bottom] = area.split(',').map(Number);
  return { left, top, right, bottom };
}

function getCropAspectRatio(crop: BookmarkCropImage): number {
  const { left, top, right, bottom } = parseCropArea(crop.Area);
  const cropWidth = right - left;
  const cropHeight = bottom - top;
  return (cropWidth * crop.AspectRatio) / cropHeight;
}

/**
 * Distribute crops into columns by always placing the next item
 * into the shortest column (by estimated height). This preserves
 * visual left-to-right, top-to-bottom order.
 */
function distributeToColumns(crops: BookmarkCropImage[], columnCount: number) {
  const columns: BookmarkCropImage[][] = Array.from({ length: columnCount }, () => []);
  const heights = new Array(columnCount).fill(0);

  for (const crop of crops) {
    // Find the shortest column
    let minIdx = 0;
    for (let i = 1; i < columnCount; i++) {
      if (heights[i] < heights[minIdx]) minIdx = i;
    }
    columns[minIdx].push(crop);
    // Estimate height contribution (1 / aspectRatio, since width is equal across columns)
    const ar = getCropAspectRatio(crop);
    heights[minIdx] += ar > 0 ? 1 / ar : 1;
  }

  return columns;
}

/**
 * Crop a full image blob to just the visible crop region.
 * Returns a small blob (~300x400px) instead of the full image (~2000x3000px).
 * This reduces browser painting cost from ~500% oversized to exact display size.
 */
async function cropImageBlob(
  blob: Blob,
  area: string,
): Promise<Blob> {
  const { left, top, right, bottom } = parseCropArea(area);
  const bitmap = await createImageBitmap(blob);
  const sx = Math.round(left * bitmap.width);
  const sy = Math.round(top * bitmap.height);
  const sw = Math.round((right - left) * bitmap.width);
  const sh = Math.round((bottom - top) * bitmap.height);

  const canvas = new OffscreenCanvas(sw, sh);
  const ctx = canvas.getContext('2d')!;
  ctx.drawImage(bitmap, sx, sy, sw, sh, 0, 0, sw, sh);
  bitmap.close();

  return canvas.convertToBlob({ type: 'image/jpeg', quality: 0.92 });
}

/**
 * Two-tier prefetch:
 * 1. Check crop-thumbnails store (already cropped, small, fast)
 * 2. For misses, read full images → crop → save thumbnail for next time
 *
 * First visit:  full image read + crop + save thumb (~slow)
 * Second visit: thumbnail read only (~instant)
 */
function usePrefetchedCache(crops: BookmarkCropImage[]) {
  const imageCacheEnabled = useAppStore((s) => s.imageCacheEnabled);
  const [cachedUrls, setCachedUrls] = useState<Map<string, string>>(new Map);
  const [loading, setLoading] = useState(false);
  const blobUrlsRef = useRef<string[]>([]);

  useEffect(() => {
    if (!imageCacheEnabled || crops.length === 0) {
      setCachedUrls(new Map());
      setLoading(false);
      return;
    }

    let cancelled = false;
    setLoading(true);

    (async () => {
      // Build thumbnail keys
      const thumbKeys = crops.map((c) => `${c.Article}:${c.Page}:${c.Area}`);

      // 1) Bulk read thumbnails (single transaction, small blobs)
      const thumbs = await getCropThumbnailsBulk(thumbKeys);

      const hits = new Map<string, Blob>();
      const misses: BookmarkCropImage[] = [];

      crops.forEach((c, i) => {
        const thumb = thumbs.get(thumbKeys[i]);
        if (thumb) {
          hits.set(`${c.Article}:${c.Page}:${c.Area}`, thumb);
        } else {
          misses.push(c);
        }
      });

      // 2) For misses, bulk read full images and crop
      if (misses.length > 0) {
        const fullKeys = misses.map((c) => ({ articleId: c.Article, page: c.Page }));
        const fulls = await getCachedImagesBulk(fullKeys);

        await Promise.all(
          misses.map(async (c) => {
            try {
              const full = fulls.get(`${c.Article}:${c.Page}`);
              if (!full) return;
              const cropped = await cropImageBlob(full.blob, c.Area);
              hits.set(`${c.Article}:${c.Page}:${c.Area}`, cropped);
              // Save thumbnail for next time (fire-and-forget)
              putCropThumbnail(`${c.Article}:${c.Page}:${c.Area}`, cropped).catch(() => {});
            } catch {
              // skip this crop
            }
          }),
        );
      }

      if (cancelled) return;

      // Revoke previous blob URLs
      for (const url of blobUrlsRef.current) URL.revokeObjectURL(url);

      const map = new Map<string, string>();
      const urls: string[] = [];
      for (const [key, blob] of hits) {
        const url = URL.createObjectURL(blob);
        urls.push(url);
        map.set(key, url);
      }
      blobUrlsRef.current = urls;
      setCachedUrls(map);
      setLoading(false);
    })().catch(() => {
      if (!cancelled) {
        setCachedUrls(new Map());
        setLoading(false);
      }
    });

    return () => {
      cancelled = true;
    };
  }, [crops, imageCacheEnabled]);

  // Cleanup blob URLs on unmount
  useEffect(
    () => () => {
      for (const url of blobUrlsRef.current) URL.revokeObjectURL(url);
    },
    [],
  );

  return { cachedUrls, loading };
}

export function CropBookmarkGrid({ crops, columnWidth, onDelete }: CropBookmarkGridProps) {
  const columnCount = useColumnCount(columnWidth);
  const gridRef = useRef<HTMLDivElement>(null);
  const scrollTimer = useRef<ReturnType<typeof setTimeout>>(undefined);
  const { cachedUrls, loading: cacheLoading } = usePrefetchedCache(crops);

  useEffect(() => {
    const handleScroll = () => {
      gridRef.current?.classList.add(styles.scrolling);
      clearTimeout(scrollTimer.current);
      scrollTimer.current = setTimeout(() => {
        gridRef.current?.classList.remove(styles.scrolling);
      }, 150);
    };
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => {
      window.removeEventListener('scroll', handleScroll);
      clearTimeout(scrollTimer.current);
    };
  }, []);

  const columns = useMemo(
    () => distributeToColumns(crops, columnCount),
    [crops, columnCount],
  );

  if (crops.length === 0) {
    return <div className={styles.empty}>No crop bookmarks</div>;
  }

  return (
    <div ref={gridRef} className={styles.grid}>
      {columns.map((col, colIdx) => (
        <div key={colIdx} className={styles.column}>
          {col.map((crop) => (
            <CropImageCard
              key={crop.Id}
              crop={crop}
              cachedUrl={cachedUrls.get(`${crop.Article}:${crop.Page}:${crop.Area}`)}
              cacheLoading={cacheLoading}
              onDelete={onDelete}
            />
          ))}
        </div>
      ))}
    </div>
  );
}
