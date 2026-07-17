import { useEffect, useMemo, useRef, useState } from 'react';
import type { MouseEvent } from 'react';
import { useNavigate } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useQuery } from '@tanstack/react-query';
import type { LlmSearchResult } from '@violet-web/shared';
import { resolveGallery, getProxyImageUrl } from '../../api/proxy';
import { useArticle } from '../../hooks/useArticle';
import { BookmarkToggleButton } from '../common/BookmarkToggleButton';
import { ArticleInfoDialog } from '../search/ArticleInfoDialog';
import { PageThumbnailDialog } from '../viewer/PageThumbnailDialog';
import styles from '../message-search/MessageSearchCard.module.css';

interface LlmSearchCardProps {
  result: LlmSearchResult;
}

interface ImageSize {
  width: number;
  height: number;
}

function middlePage(pages: number[]): number {
  return pages[Math.floor(pages.length / 2)] ?? pages[0] ?? 1;
}

export function LlmSearchCard({ result }: LlmSearchCardProps) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const cardRef = useRef<HTMLDivElement>(null);
  const [visible, setVisible] = useState(false);
  const [imageSize, setImageSize] = useState<ImageSize | null>(null);
  const [showInfoDialog, setShowInfoDialog] = useState(false);
  const [showPageThumbnails, setShowPageThumbnails] = useState(false);
  const { data: article } = useArticle(showInfoDialog ? result.work : 0);
  const pageNumber = middlePage(result.pages);
  const pageIndex = Math.max(0, pageNumber - 1);

  useEffect(() => {
    const element = cardRef.current;
    if (!element) return;
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setVisible(true);
          observer.disconnect();
        }
      },
      { rootMargin: '400px' },
    );
    observer.observe(element);
    return () => observer.disconnect();
  }, []);

  const { data: gallery, isError } = useQuery({
    queryKey: ['llmSearchGallery', result.work],
    queryFn: () => resolveGallery(result.work),
    enabled: visible,
    staleTime: 30 * 60 * 1000,
    retry: 1,
  });

  const referer = `https://hitomi.la/reader/${result.work}.html`;
  const sourceUrl = gallery?.urls[pageIndex];
  const imageUrl = sourceUrl ? getProxyImageUrl(sourceUrl, referer) : null;
  const aspectRatio = imageSize ? `${imageSize.width} / ${imageSize.height}` : '2 / 3';
  const thumbnailUrls = useMemo(() => {
    if (!gallery) return [];
    const urls = gallery.smallThumbnails.length > 0
      ? gallery.smallThumbnails
      : gallery.bigThumbnails.length > 0
      ? gallery.bigThumbnails
      : gallery.urls;
    return urls.map((url) => getProxyImageUrl(url, referer));
  }, [gallery, referer]);

  const openViewer = () => navigate(`/viewer/${result.work}?page=${pageNumber}`);
  const openInfoDialog = (event: MouseEvent) => {
    event.stopPropagation();
    setShowInfoDialog(true);
  };
  const openPageThumbnails = (event: MouseEvent) => {
    event.stopPropagation();
    setShowPageThumbnails(true);
  };
  const handlePageSelect = (selectedPageIndex: number) => {
    navigate(`/viewer/${result.work}?page=${selectedPageIndex + 1}`);
  };

  return (
    <>
      <div ref={cardRef} className={`${styles.card} bookmark-hover-scope`} onClick={openViewer}>
        <div className={styles.imageFrame} style={{ aspectRatio }}>
          <BookmarkToggleButton articleId={result.work} />
          {imageUrl ? (
            <>
              <div className={styles.scoreBar}>
                <span>{t('llmSearch.rerankScore')}: {result.rerankScore?.toFixed(4) ?? '-'}</span>
                <span>{t('llmSearch.embedScore')}: {result.embedScore.toFixed(4)}</span>
              </div>
              <img
                className={styles.image}
                src={imageUrl}
                loading="lazy"
                onLoad={(event) => {
                  const image = event.currentTarget;
                  setImageSize({ width: image.naturalWidth, height: image.naturalHeight });
                }}
                alt={t('llmSearch.resultImageAlt', { id: result.work, page: pageNumber })}
              />
            </>
          ) : (
            <div className={styles.placeholder}>
              {isError
                ? t('llmSearch.imageError')
                : visible && gallery
                ? t('llmSearch.invalidPage')
                : t('viewer.loading')}
            </div>
          )}
        </div>
        <div className={styles.overlay}>
          <button type="button" className={styles.articleBtn} onClick={openInfoDialog}>
            #{result.work}
          </button>
          {' · '}
          <button type="button" className={styles.pageBtn} onClick={openPageThumbnails}>
            p{pageNumber}
          </button>
        </div>
      </div>

      {showInfoDialog && article && (
        <ArticleInfoDialog article={article} onClose={() => setShowInfoDialog(false)} />
      )}
      {showPageThumbnails && gallery && (
        <PageThumbnailDialog
          thumbnailUrls={thumbnailUrls}
          currentPage={pageIndex}
          totalPages={gallery.urls.length}
          twoPageMode={false}
          coverPageMode="normal"
          onPageSelect={handlePageSelect}
          onClose={() => setShowPageThumbnails(false)}
        />
      )}
    </>
  );
}
