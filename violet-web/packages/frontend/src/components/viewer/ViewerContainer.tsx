import { useViewerStore } from '../../stores/viewer-store';
import { VerticalReader } from './VerticalReader';
import { HorizontalReader } from './HorizontalReader';
import { PagedReader } from './PagedReader';
import { ViewerOverlay } from './ViewerOverlay';
import styles from './ViewerContainer.module.css';
import type { IntensityTimeline } from '@violet-web/shared';

interface ViewerContainerProps {
  galleryId: number;
  imageUrls: string[];
  thumbnailUrls: string[];
  currentPage: number;
  totalPages: number;
  onPageChange: (page: number) => void;
  onClose: () => void;
  intensityTimeline?: IntensityTimeline;
}

export function ViewerContainer({
  galleryId,
  imageUrls,
  thumbnailUrls,
  currentPage,
  totalPages,
  onPageChange,
  onClose,
  intensityTimeline,
}: ViewerContainerProps) {
  const { viewMode, pageMode, readDirection, padding, twoPageMode, coverPageMode } =
    useViewerStore();

  const rtl = readDirection === 'rtl';

  return (
    <div className={styles.container}>
      {pageMode === 'paged' ? (
        <PagedReader
          imageUrls={imageUrls}
          currentPage={currentPage}
          onPageChange={onPageChange}
          rtl={rtl}
          twoPageMode={twoPageMode}
          coverPageMode={coverPageMode}
          galleryId={galleryId}
        />
      ) : viewMode === 'vertical' ? (
        <VerticalReader
          imageUrls={imageUrls}
          currentPage={currentPage}
          onPageChange={onPageChange}
          padding={padding}
          galleryId={galleryId}
        />
      ) : (
        <HorizontalReader
          imageUrls={imageUrls}
          currentPage={currentPage}
          onPageChange={onPageChange}
          rtl={rtl}
          galleryId={galleryId}
        />
      )}
      <ViewerOverlay
        galleryId={galleryId}
        currentPage={currentPage}
        totalPages={totalPages}
        onPageChange={onPageChange}
        onClose={onClose}
        thumbnailUrls={thumbnailUrls}
        imageUrls={imageUrls}
        intensityTimeline={intensityTimeline}
      />
    </div>
  );
}
