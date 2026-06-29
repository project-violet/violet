import { useState, useRef, useEffect } from 'react';
import styles from './LazyImage.module.css';

interface LazyImageProps {
  src: string;
  alt?: string;
  className?: string;
  onClick?: () => void;
  onLoad?: () => void;
}

export function LazyImage({ src, alt = '', className, onClick, onLoad }: LazyImageProps) {
  const [loaded, setLoaded] = useState(false);
  const [inView, setInView] = useState(false);
  const [error, setError] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setInView(true);
          observer.disconnect();
        }
      },
      { rootMargin: '200px' },
    );

    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  const retry = () => {
    setError(false);
    setLoaded(false);
  };

  return (
    <div ref={ref} className={`${styles.wrapper} ${className ?? ''}`} onClick={onClick}>
      {inView && !error && (
        <img
          src={src}
          alt={alt}
          className={`${styles.image} ${loaded ? styles.loaded : ''}`}
          onLoad={() => { setLoaded(true); onLoad?.(); }}
          onError={() => setError(true)}
          loading="lazy"
        />
      )}
      {error && (
        <div className={styles.error} onClick={retry}>
          Failed to load. Click to retry.
        </div>
      )}
      {!loaded && !error && <div className={styles.placeholder} />}
    </div>
  );
}
