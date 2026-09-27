import { useState, useRef, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { useCachedImage } from '../../hooks/useCachedImage';
import type { ImageDimensions } from '@violet-web/shared';
import styles from './ViewerImage.module.css';

interface ViewerImageProps {
  src: string;
  alt?: string;
  active?: boolean; // If false, show placeholder instead of loading image
  onLoad?: () => void;
  cacheKey?: { galleryId: number; page: number };
  reserveSpace?: boolean;
  dimensions?: ImageDimensions | null;
  onDimensions?: (size: ImageDimensions) => void;
}

const MAX_RETRIES = 10;
const RETRY_DELAY = 1500; // 1.5 seconds
const ACTIVE_DEBOUNCE = 150; // ms - prevents loading images during fast scrolling

export function ViewerImage({ src, alt = '', active = true, onLoad, cacheKey, reserveSpace = false, dimensions, onDimensions }: ViewerImageProps) {
  const { t } = useTranslation();
  const { src: effectiveSrc, onLoadSuccess } = useCachedImage(src, cacheKey ?? null);
  const [loaded, setLoaded] = useState(false);
  const [error, setError] = useState(false);
  const [retryCount, setRetryCount] = useState(0);
  const [shouldRender, setShouldRender] = useState(active);
  const imgRef = useRef<HTMLImageElement>(null);
  const retryTimeoutRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const activeTimeoutRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

  useEffect(() => {
    setLoaded(false);
    setError(false);
    setRetryCount(0);
  }, [effectiveSrc]);

  // Debounce active state: only render after staying active for a short period
  useEffect(() => {
    if (active) {
      activeTimeoutRef.current = setTimeout(() => {
        setShouldRender(true);
      }, ACTIVE_DEBOUNCE);
    } else {
      setShouldRender(false);
      if (activeTimeoutRef.current) {
        clearTimeout(activeTimeoutRef.current);
      }
    }
    return () => {
      if (activeTimeoutRef.current) {
        clearTimeout(activeTimeoutRef.current);
      }
    };
  }, [active]);

  useEffect(() => {
    return () => {
      if (retryTimeoutRef.current) {
        clearTimeout(retryTimeoutRef.current);
      }
    };
  }, []);

  // Reserve the same page box while loading, failed, or outside the load window.
  const containerClass = `${styles.container} ${reserveSpace ? styles.reserved : ''}`;
  const reservedStyle = reserveSpace ? {
    width: dimensions ? `min(100%, ${dimensions.width}px)` : '100%',
    aspectRatio: dimensions ? `${dimensions.width} / ${dimensions.height}` : '2 / 3',
  } : undefined;

  // If not active, release the bitmap but keep its layout space.
  if (!shouldRender) {
    return <div className={containerClass} style={reservedStyle} />;
  }

  const handleError = () => {
    if (retryCount < MAX_RETRIES) {
      retryTimeoutRef.current = setTimeout(() => {
        setRetryCount((c) => c + 1);
      }, RETRY_DELAY);
    } else {
      setError(true);
    }
  };

  const manualRetry = () => {
    setError(false);
    setRetryCount(0);
  };

  const handleLoad = () => {
    const image = imgRef.current;
    if (image && image.naturalWidth > 0 && image.naturalHeight > 0) {
      onDimensions?.({ width: image.naturalWidth, height: image.naturalHeight });
    }
    setLoaded(true);
    onLoadSuccess();
    onLoad?.();
  };

  return (
    <div className={containerClass} style={reservedStyle}>
      {!error && effectiveSrc ? (
        <img
          ref={imgRef}
          key={`${effectiveSrc}-${retryCount}`}
          src={effectiveSrc}
          alt={alt}
          className={`${styles.image} ${loaded ? styles.loaded : ''}`}
          onLoad={handleLoad}
          onError={handleError}
        />
      ) : error ? (
        <div className={styles.error} onClick={manualRetry}>
          {t('viewer.loadError', { max: MAX_RETRIES })}
        </div>
      ) : null}
      {!loaded && !error && (
        <div className={styles.loading}>
          {retryCount > 0
            ? t('viewer.retrying', { current: retryCount, max: MAX_RETRIES })
            : t('viewer.loading')}
        </div>
      )}
    </div>
  );
}
