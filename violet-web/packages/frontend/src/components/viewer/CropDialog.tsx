import { useState, useRef, useCallback, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { useAddCropBookmark } from '../../hooks/useBookmarks';
import styles from './CropDialog.module.css';

interface CropDialogProps {
  galleryId: number;
  imageUrls: string[];
  visiblePages: number[];
  onClose: () => void;
}

interface DragState {
  startX: number;
  startY: number;
  endX: number;
  endY: number;
}

export function CropDialog({ galleryId, imageUrls, visiblePages, onClose }: CropDialogProps) {
  const [selectedPage, setSelectedPage] = useState<number | null>(
    visiblePages.length === 1 ? visiblePages[0] : null,
  );
  const [drag, setDrag] = useState<DragState | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [confirmed, setConfirmed] = useState(false);
  const imgRef = useRef<HTMLImageElement>(null);
  const addCrop = useAddCropBookmark();
  const { t } = useTranslation();

  // Close on Escape
  useEffect(() => {
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', handleKey);
    return () => window.removeEventListener('keydown', handleKey);
  }, [onClose]);

  const getImageRect = useCallback(() => {
    return imgRef.current?.getBoundingClientRect() ?? null;
  }, []);

  const handleMouseDown = useCallback(
    (e: React.MouseEvent) => {
      const rect = getImageRect();
      if (!rect) return;

      const x = e.clientX;
      const y = e.clientY;

      // Only start if clicking within the image bounds
      if (x < rect.left || x > rect.right || y < rect.top || y > rect.bottom) return;

      setDrag({ startX: x, startY: y, endX: x, endY: y });
      setIsDragging(true);
      setConfirmed(false);
    },
    [getImageRect],
  );

  const handleMouseMove = useCallback(
    (e: React.MouseEvent) => {
      if (!isDragging || !drag) return;
      setDrag((prev) => (prev ? { ...prev, endX: e.clientX, endY: e.clientY } : null));
    },
    [isDragging, drag],
  );

  const handleMouseUp = useCallback(() => {
    if (!isDragging || !drag) return;
    setIsDragging(false);

    const rect = getImageRect();
    if (!rect) return;

    // Check minimum size (at least 10px)
    const width = Math.abs(drag.endX - drag.startX);
    const height = Math.abs(drag.endY - drag.startY);
    if (width < 10 || height < 10) {
      setDrag(null);
      return;
    }

    setConfirmed(true);
  }, [isDragging, drag, getImageRect]);

  const handleSave = useCallback(() => {
    if (!drag || selectedPage === null) return;

    const rect = getImageRect();
    const img = imgRef.current;
    if (!rect || !img) return;

    // Normalize coordinates to 0~1 relative to image
    const left = Math.max(0, Math.min(1, (Math.min(drag.startX, drag.endX) - rect.left) / rect.width));
    const top = Math.max(0, Math.min(1, (Math.min(drag.startY, drag.endY) - rect.top) / rect.height));
    const right = Math.max(0, Math.min(1, (Math.max(drag.startX, drag.endX) - rect.left) / rect.width));
    const bottom = Math.max(0, Math.min(1, (Math.max(drag.startY, drag.endY) - rect.top) / rect.height));

    const aspectRatio = img.naturalWidth / img.naturalHeight;

    addCrop.mutate(
      {
        Article: galleryId,
        Page: selectedPage,
        Area: `${left},${top},${right},${bottom}`,
        AspectRatio: aspectRatio,
      },
      {
        onSuccess: () => onClose(),
      },
    );
  }, [drag, selectedPage, getImageRect, galleryId, addCrop, onClose]);

  const handleReset = useCallback(() => {
    setDrag(null);
    setConfirmed(false);
  }, []);

  // Render selection rectangle
  const getSelectionStyle = useCallback((): React.CSSProperties | null => {
    if (!drag) return null;

    const left = Math.min(drag.startX, drag.endX);
    const top = Math.min(drag.startY, drag.endY);
    const width = Math.abs(drag.endX - drag.startX);
    const height = Math.abs(drag.endY - drag.startY);

    return { left, top, width, height };
  }, [drag]);

  // Page selection mode
  if (selectedPage === null) {
    return (
      <div className={styles.backdrop}>
        <div className={styles.header}>
          <span className={styles.headerTitle}>{t('crop.selectPage')}</span>
          <div className={styles.headerActions}>
            <button className={styles.headerBtn} onClick={onClose}>
              {t('crop.cancel')}
            </button>
          </div>
        </div>
        <div className={styles.pageSelectContainer}>
          {visiblePages.map((pageIdx) => (
            <div
              key={pageIdx}
              className={styles.pageSelectItem}
              onClick={() => setSelectedPage(pageIdx)}
            >
              <img src={imageUrls[pageIdx]} alt={`Page ${pageIdx + 1}`} />
              <div className={styles.pageSelectLabel}>{t('crop.page', { page: pageIdx + 1 })}</div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  // Crop mode
  const selectionStyle = getSelectionStyle();

  return (
    <div className={styles.backdrop}>
      <div className={styles.header}>
        <span className={styles.headerTitle}>
          {t('crop.dragToSelect', { page: selectedPage + 1 })}
        </span>
        <div className={styles.headerActions}>
          {confirmed && (
            <>
              <button className={styles.headerBtn} onClick={handleReset}>
                {t('crop.reselect')}
              </button>
              <button
                className={`${styles.headerBtn} ${styles.saveBtn}`}
                onClick={handleSave}
                disabled={addCrop.isPending}
              >
                {t('crop.save')}
              </button>
            </>
          )}
          <button className={styles.headerBtn} onClick={onClose}>
            {t('crop.cancel')}
          </button>
        </div>
      </div>
      <div className={styles.cropContainer}>
        <img
          ref={imgRef}
          className={styles.cropImage}
          src={imageUrls[selectedPage]}
          alt={`Page ${selectedPage + 1}`}
          draggable={false}
        />
        <div
          className={styles.cropOverlay}
          onMouseDown={handleMouseDown}
          onMouseMove={handleMouseMove}
          onMouseUp={handleMouseUp}
          onMouseLeave={handleMouseUp}
        />
        {selectionStyle && <div className={styles.selectionRect} style={selectionStyle} />}
      </div>
    </div>
  );
}
