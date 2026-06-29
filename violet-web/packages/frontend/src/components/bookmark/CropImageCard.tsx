import { useState, useEffect, useRef, useCallback } from 'react';
import { useNavigate } from 'react-router';
import { useQuery } from '@tanstack/react-query';
import type { BookmarkCropImage } from '@violet-web/shared';
import { resolveGallery, getProxyImageUrl } from '../../api/proxy';
import { useArticle } from '../../hooks/useArticle';
import { useAppStore } from '../../stores/app-store';
import { putCachedImage } from '../../services/image-cache';
import { ArticleInfoDialog } from '../search/ArticleInfoDialog';
import styles from './CropImageCard.module.css';

interface CropImageCardProps {
  crop: BookmarkCropImage;
  cachedUrl?: string;
  cacheLoading?: boolean;
  onDelete: (id: number) => void;
}

function parseCropArea(area: string) {
  const [left, top, right, bottom] = area.split(',').map(Number);
  return { left, top, right, bottom };
}

export function CropImageCard({ crop, cachedUrl, cacheLoading, onDelete }: CropImageCardProps) {
  const navigate = useNavigate();
  const cardRef = useRef<HTMLDivElement>(null);
  const [visible, setVisible] = useState(false);
  const [showInfoDialog, setShowInfoDialog] = useState(false);
  const { data: article } = useArticle(showInfoDialog ? crop.Article : 0);
  const imageCacheEnabled = useAppStore((s) => s.imageCacheEnabled);
  const imageCacheMaxSizeMB = useAppStore((s) => s.imageCacheMaxSizeMB);
  const savingRef = useRef(false);

  // IntersectionObserver for lazy loading
  useEffect(() => {
    const el = cardRef.current;
    if (!el) return;
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setVisible(true);
          observer.disconnect();
        }
      },
      { rootMargin: '200px' },
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  const { left, top, right, bottom } = parseCropArea(crop.Area);
  const cropWidth = right - left;
  const cropHeight = bottom - top;
  const cropAspectRatio = (cropWidth * crop.AspectRatio) / cropHeight;

  // Only fetch gallery URL if no cached version and cache check is done
  const { data: gallery } = useQuery({
    queryKey: ['gallery', crop.Article],
    queryFn: () => resolveGallery(crop.Article),
    enabled: visible && !cachedUrl && !cacheLoading,
    staleTime: 5 * 60 * 1000,
  });

  const proxyUrl = gallery
    ? getProxyImageUrl(
        gallery.urls[crop.Page],
        `https://hitomi.la/reader/${crop.Article}.html`,
      )
    : null;

  // Use cached blob URL if available, otherwise proxy URL
  const imageUrl = cachedUrl ?? proxyUrl;

  const handleClick = useCallback(() => {
    navigate(`/viewer/${crop.Article}?p=${crop.Page}`);
  }, [navigate, crop.Article, crop.Page]);

  const handleDelete = useCallback(
    (e: React.MouseEvent) => {
      e.stopPropagation();
      onDelete(crop.Id);
    },
    [onDelete, crop.Id],
  );

  // Save to cache on load for cache misses
  const handleLoad = useCallback(() => {
    if (cachedUrl || !proxyUrl || !imageCacheEnabled || savingRef.current) return;
    savingRef.current = true;

    fetch(proxyUrl)
      .then((res) => {
        if (!res.ok) throw new Error('fetch failed');
        const contentType = res.headers.get('content-type') || 'image/jpeg';
        return res.blob().then((blob) => ({ blob, contentType }));
      })
      .then(({ blob, contentType }) => {
        const maxBytes = imageCacheMaxSizeMB * 1024 * 1024;
        return putCachedImage(crop.Article, crop.Page, blob, contentType, maxBytes);
      })
      .catch(() => {})
      .finally(() => {
        savingRef.current = false;
      });
  }, [cachedUrl, proxyUrl, imageCacheEnabled, imageCacheMaxSizeMB, crop.Article, crop.Page]);

  return (
    <>
      <div ref={cardRef} className={styles.card} onClick={handleClick}>
        <div
          className={styles.imageWrapper}
          style={{ aspectRatio: String(cropAspectRatio) }}
        >
          {cachedUrl ? (
            <img
              className={styles.croppedImage}
              src={cachedUrl}
              loading="lazy"
            />
          ) : proxyUrl ? (
            <img
              className={styles.image}
              src={proxyUrl}
              loading="lazy"
              onLoad={handleLoad}
              style={{
                width: `${(1 / cropWidth) * 100}%`,
                left: `${(-left / cropWidth) * 100}%`,
                top: `${(-top / cropHeight) * 100}%`,
              }}
            />
          ) : (
            visible && <div className={styles.placeholder}>Loading...</div>
          )}
        </div>
        {crop.Id >= 0 && (
          <button className={styles.deleteBtn} onClick={handleDelete} title="Delete">
            ×
          </button>
        )}
        <div className={styles.overlay}>
          <span
            className={styles.articleLink}
            onClick={(e) => { e.stopPropagation(); setShowInfoDialog(true); }}
          >
            #{crop.Article}
          </span>
          {' · p'}{crop.Page + 1}
        </div>
      </div>
      {showInfoDialog && article && (
        <ArticleInfoDialog article={article} onClose={() => setShowInfoDialog(false)} />
      )}
    </>
  );
}
