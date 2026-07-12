import { useState, type MouseEvent } from 'react';
import { createPortal } from 'react-dom';
import { useCachedThumbnail } from '../../hooks/useCachedThumbnail';
import styles from './WorkThumbnail.module.css';

interface WorkThumbnailProps {
  articleId: number;
  size?: 'graph' | 'activity';
}

export function WorkThumbnail({ articleId, size = 'graph' }: WorkThumbnailProps) {
  const [previewPosition, setPreviewPosition] = useState<{ left: number; top: number } | null>(null);
  const { src, onLoadSuccess } = useCachedThumbnail(articleId);

  const handlePreviewMove = (event: MouseEvent) => {
    if (!src) return;
    const previewWidth = 280;
    const previewHeight = 380;
    const gap = 18;
    const leftSide = event.clientX - previewWidth - gap;
    setPreviewPosition({
      left: leftSide >= gap ? leftSide : Math.max(gap, Math.min(event.clientX + gap, window.innerWidth - previewWidth - gap)),
      top: Math.max(gap, Math.min(event.clientY + gap, window.innerHeight - previewHeight - gap)),
    });
  };

  return (
    <>
      <span
        className={`${styles.thumbnail} ${styles[size]}`}
        aria-hidden="true"
        onMouseEnter={handlePreviewMove}
        onMouseMove={handlePreviewMove}
        onMouseLeave={() => setPreviewPosition(null)}
      >
        {src ? <img src={src} alt="" loading="lazy" onLoad={onLoadSuccess} /> : <span className={styles.empty}>#{articleId}</span>}
      </span>
      {previewPosition && src && createPortal(
        <div className={styles.preview} style={{ left: previewPosition.left, top: previewPosition.top }}>
          <img src={src} alt="" />
        </div>,
        document.body,
      )}
    </>
  );
}
