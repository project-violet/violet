import { useParams, useNavigate, useSearchParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useImageList } from '../hooks/useImageList';
import { useViewer } from '../hooks/useViewer';
import { useInsertReadLog, useUpdateReadLog } from '../hooks/useReadHistory';
import { useViewerStore } from '../stores/viewer-store';
import { useAppStore } from '../stores/app-store';
import { ViewerContainer } from '../components/viewer/ViewerContainer';
import { ResumeDialog } from '../components/viewer/ResumeDialog';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import { getProxyImageUrl } from '../api/proxy';
import { getLastPage } from '../api/history';
import { cleanupExpired } from '../services/image-cache';
import { useEffect, useRef, useState } from 'react';

export function ViewerPage() {
  const { t } = useTranslation();
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const galleryId = parseInt(id!);
  const { data: imageList, isLoading } = useImageList(galleryId);

  const totalPages = imageList?.urls.length ?? 0;
  // URL uses 1-based indexing, convert to 0-based for internal use
  const pageParam = parseInt(searchParams.get('page') || '1');
  const hasExplicitPage = searchParams.has('page');
  const initialPage = Math.max(0, pageParam - 1);
  const { currentPage, goToPage } = useViewer(totalPages, initialPage);

  const insertLog = useInsertReadLog();
  const updateLog = useUpdateReadLog();
  const logIdRef = useRef<number | null>(null);
  const { imageCacheEnabled, imageCacheExpireDays } = useAppStore();
  const resumePromptEnabled = useViewerStore((s) => s.resumePromptEnabled);

  const [resumePage, setResumePage] = useState<number | null>(null);
  const [showResumeDialog, setShowResumeDialog] = useState(false);

  // Cleanup expired cache on mount
  useEffect(() => {
    if (imageCacheEnabled) {
      cleanupExpired(imageCacheExpireDays).catch(() => {});
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Force hide overlay on mount
  useEffect(() => {
    useViewerStore.setState({ showOverlay: false });
  }, []);

  // ESC key to exit viewer
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        navigate(-1);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [navigate]);

  // Check for resume position on mount
  useEffect(() => {
    if (!galleryId || hasExplicitPage || !resumePromptEnabled) return;
    getLastPage(String(galleryId)).then((page) => {
      if (page != null && page > 0) {
        setResumePage(page);
        setShowResumeDialog(true);
      }
    }).catch(() => {});
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [galleryId, resumePromptEnabled]);

  // Insert read log on mount
  useEffect(() => {
    if (!galleryId) return;
    insertLog.mutate(
      { Article: String(galleryId), Type: 0 },
      {
        onSuccess: (data) => {
          logIdRef.current = Number(data.Id);
        },
      },
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [galleryId]);

  // Update read log on page change
  useEffect(() => {
    if (logIdRef.current == null) return;
    updateLog.mutate({ id: logIdRef.current, LastPage: currentPage });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentPage]);

  // Update URL without navigation (use 1-based indexing in URL)
  useEffect(() => {
    const url = `/viewer/${galleryId}?page=${currentPage + 1}`;
    window.history.replaceState(null, '', url);
  }, [currentPage, galleryId]);

  if (isLoading) {
    return (
      <div style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: '#000',
        zIndex: 100,
      }}>
        <LoadingSpinner />
      </div>
    );
  }

  if (!imageList || imageList.urls.length === 0) {
    return (
      <div style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: '#000',
        color: '#fff',
        zIndex: 100,
      }}>
        {t('viewer.noImages')}
      </div>
    );
  }

  const referer = `https://hitomi.la/reader/${galleryId}.html`;
  const proxyUrls = imageList.urls.map((url) => getProxyImageUrl(url, referer));
  const thumbnailUrls = (imageList.smallThumbnails ?? []).map((url) =>
    getProxyImageUrl(url, referer),
  );

  return (
    <>
      <ViewerContainer
        galleryId={galleryId}
        imageUrls={proxyUrls}
        thumbnailUrls={thumbnailUrls}
        currentPage={currentPage}
        totalPages={totalPages}
        onPageChange={goToPage}
        onClose={() => navigate(-1)}
      />
      {showResumeDialog && resumePage != null && (
        <ResumeDialog
          lastPage={resumePage}
          totalPages={totalPages}
          onResume={() => {
            goToPage(resumePage);
            setShowResumeDialog(false);
          }}
          onStartOver={() => setShowResumeDialog(false)}
        />
      )}
    </>
  );
}
