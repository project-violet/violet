import { useRef, useEffect, useLayoutEffect, useCallback, useState } from 'react';
import type { ImageDimensions } from '@violet-web/shared';
import { ViewerImage } from './ViewerImage';
import { captureAnchor, pageAtOffset, restoreAnchor, validDimensions, type ReadingAnchor } from './scroll-layout';
import styles from './VerticalReader.module.css';

const PREFETCH_RANGE = 5;

interface VerticalReaderProps {
  imageUrls: string[];
  imageDimensions?: (ImageDimensions | null)[];
  currentPage: number;
  onPageChange: (page: number) => void;
  onTap: () => void;
  padding: number;
  galleryId: number;
}

export function VerticalReader({ imageUrls, imageDimensions, currentPage, onPageChange, onTap, padding, galleryId }: VerticalReaderProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const imageRefs = useRef<(HTMLDivElement | null)[]>([]);
  const observedPageChange = useRef<number | null>(null);
  const pendingAnchor = useRef<ReadingAnchor | null>(null);
  const [measuredSizes, setMeasuredSizes] = useState<Record<number, ImageDimensions>>({});

  const pageBox = useCallback((page: number) => {
    const container = containerRef.current!;
    const rect = imageRefs.current[page]!.getBoundingClientRect();
    return { top: rect.top - container.getBoundingClientRect().top + container.scrollTop, height: rect.height };
  }, []);

  const sizeForPage = (page: number) => {
    const size = measuredSizes[page] ?? imageDimensions?.[page];
    return validDimensions(size) ? size : null;
  };

  const handleDimensions = (page: number, size: ImageDimensions) => {
    const previous = sizeForPage(page);
    if (!validDimensions(size) || (previous?.width === size.width && previous.height === size.height)) return;
    const container = containerRef.current;
    if (container && !pendingAnchor.current) {
      // Capture once per React commit, before any unknown page changes size.
      pendingAnchor.current = captureAnchor(imageUrls.length, pageBox,
        container.scrollTop, container.clientHeight, container.scrollHeight);
    }
    setMeasuredSizes(previousSizes => ({ ...previousSizes, [page]: size }));
  };

  useLayoutEffect(() => {
    const container = containerRef.current;
    const anchor = pendingAnchor.current;
    pendingAnchor.current = null;
    if (container && anchor) {
      container.scrollTop = restoreAnchor(anchor, pageBox, container.clientHeight, container.scrollHeight);
    }
  }, [measuredSizes, pageBox]);

  // Slider/keyboard/resume jumps go directly to their target. Sweeping smoothly
  // through hundreds of unloaded pages causes unnecessary loads and page updates.
  useLayoutEffect(() => {
    if (observedPageChange.current === currentPage) {
      observedPageChange.current = null;
      return;
    }
    observedPageChange.current = null;
    const container = containerRef.current;
    if (container && imageRefs.current[currentPage]) container.scrollTop = pageBox(currentPage).top;
  }, [currentPage, pageBox]);

  useEffect(() => {
    const container = containerRef.current;
    if (!container || !imageUrls.length) return;
    let frame = 0;
    const update = () => {
      frame = 0;
      const atEnd = container.scrollHeight - container.clientHeight - container.scrollTop <= 2;
      const page = atEnd ? imageUrls.length - 1 : pageAtOffset(imageUrls.length, pageBox,
        container.scrollTop + container.clientHeight * 0.35);
      if (page !== currentPage) {
        observedPageChange.current = page;
        onPageChange(page);
      }
    };
    const schedule = () => { if (!frame) frame = requestAnimationFrame(update); };
    container.addEventListener('scroll', schedule, { passive: true });
    const resize = new ResizeObserver(schedule);
    resize.observe(container);
    return () => {
      container.removeEventListener('scroll', schedule);
      resize.disconnect();
      cancelAnimationFrame(frame);
    };
  }, [imageUrls.length, currentPage, onPageChange, pageBox]);

  const handleClick = useCallback((event: React.MouseEvent<HTMLDivElement>) => {
    if ((event.target as HTMLElement).closest('button, a, input')) return;
    onTap();
  }, [onTap]);

  return (
    <div ref={containerRef} className={styles.container} onClick={handleClick}>
      {imageUrls.map((url, i) => (
        <div key={i} ref={(el) => { imageRefs.current[i] = el; }} data-page={i}
          className={styles.page} style={{ padding: `${padding}px 0` }}>
          <ViewerImage src={url} alt={`Page ${i + 1}`} active={Math.abs(i - currentPage) <= PREFETCH_RANGE}
            cacheKey={{ galleryId, page: i }} reserveSpace dimensions={sizeForPage(i)}
            onDimensions={size => handleDimensions(i, size)} />
        </div>
      ))}
    </div>
  );
}
