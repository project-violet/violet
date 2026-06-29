import { useState, useRef, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { useCachedImage } from '../../hooks/useCachedImage';
import styles from './ViewerImage.module.css';

interface ViewerImageProps {
  src: string;
  alt?: string;
  active?: boolean; // If false, show placeholder instead of loading image
  onLoad?: () => void;
  cacheKey?: { galleryId: number; page: number };
}

const MAX_RETRIES = 10;
const RETRY_DELAY = 1500; // 1.5 seconds
const ACTIVE_DEBOUNCE = 150; // ms - prevents loading images during fast scrolling

export function ViewerImage({ src, alt = '', active = true, onLoad, cacheKey }: ViewerImageProps) {
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

  // If not active, show placeholder
  if (!shouldRender) {
    return <div className={styles.container} />;
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
    setLoaded(true);
    onLoadSuccess();
    onLoad?.();
  };

  return (
    <div className={styles.container}>
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
