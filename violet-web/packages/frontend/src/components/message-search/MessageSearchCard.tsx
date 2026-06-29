import { useEffect, useMemo, useRef, useState } from 'react';
import type { MouseEvent } from 'react';
import { useNavigate } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useQuery } from '@tanstack/react-query';
import type { MessageSearchResult } from '@violet-web/shared';
import { resolveGallery, getProxyImageUrl } from '../../api/proxy';
import { useArticle } from '../../hooks/useArticle';
import { BookmarkToggleButton } from '../common/BookmarkToggleButton';
import { ArticleInfoDialog } from '../search/ArticleInfoDialog';
import { PageThumbnailDialog } from '../viewer/PageThumbnailDialog';
import styles from './MessageSearchCard.module.css';

interface MessageSearchCardProps {
  result: MessageSearchResult;
}

interface ImageSize {
  width: number;
  height: number;
}

function clampPercent(value: number): number {
  return Math.max(0, Math.min(100, value));
}

export function MessageSearchCard({ result }: MessageSearchCardProps) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const cardRef = useRef<HTMLDivElement>(null);
  const [visible, setVisible] = useState(false);
  const [imageSize, setImageSize] = useState<ImageSize | null>(null);
  const [showInfoDialog, setShowInfoDialog] = useState(false);
  const [showPageThumbnails, setShowPageThumbnails] = useState(false);
  const { data: article } = useArticle(showInfoDialog ? result.articleId : 0);

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
      { rootMargin: '400px' },
    );

    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  const { data: gallery, isError } = useQuery({
    queryKey: ['messageSearchGallery', result.articleId],
    queryFn: () => resolveGallery(result.articleId),
    enabled: visible,
    staleTime: 30 * 60 * 1000,
    retry: 1,
  });

  const referer = `https://hitomi.la/reader/${result.articleId}.html`;
  const sourceUrl = gallery?.urls[result.page];
  const imageUrl = sourceUrl ? getProxyImageUrl(sourceUrl, referer) : null;

  const thumbnailUrls = useMemo(() => {
    if (!gallery) return [];
    const urls = gallery.smallThumbnails.length > 0
      ? gallery.smallThumbnails
      : gallery.bigThumbnails.length > 0
      ? gallery.bigThumbnails
      : gallery.urls;
    return urls.map((url) => getProxyImageUrl(url, referer));
  }, [gallery, referer]);

  const matchBox = useMemo(() => {
    if (!imageSize) return null;

    const [x1, y1, x2, y2] = result.rect;
    const left = clampPercent((x1 / imageSize.width) * 100);
    const top = clampPercent((y1 / imageSize.height) * 100);
    const width = clampPercent(((x2 - x1) / imageSize.width) * 100);
    const height = clampPercent(((y2 - y1) / imageSize.height) * 100);

    return { left, top, width, height };
  }, [imageSize, result.rect]);

  const aspectRatio = imageSize ? `${imageSize.width} / ${imageSize.height}` : '2 / 3';

  const openViewer = () => {
    navigate(`/viewer/${result.articleId}?page=${result.page + 1}`);
  };

  const openInfoDialog = (event: MouseEvent) => {
    event.stopPropagation();
    setShowInfoDialog(true);
  };

  const openPageThumbnails = (event: MouseEvent) => {
    event.stopPropagation();
    setShowPageThumbnails(true);
  };

  const handlePageSelect = (pageIndex: number) => {
    navigate(`/viewer/${result.articleId}?page=${pageIndex + 1}`);
  };

  return (
    <>
      <div ref={cardRef} className={`${styles.card} bookmark-hover-scope`} onClick={openViewer}>
        <div className={styles.imageFrame} style={{ aspectRatio }}>
          <BookmarkToggleButton articleId={result.articleId} />

          {imageUrl ? (
            <>
              <div className={styles.scoreBar}>
                <span>{t('messageSearch.score')}: {result.matchScore}</span>
                <span>{t('messageSearch.correctness')}: {(result.correctness * 100).toFixed(2)}%</span>
              </div>
              <img
                className={styles.image}
                src={imageUrl}
                loading="lazy"
                onLoad={(event) => {
                  const img = event.currentTarget;
                  setImageSize({
                    width: img.naturalWidth,
                    height: img.naturalHeight,
                  });
                }}
                alt={t('messageSearch.resultImageAlt', {
                  id: result.articleId,
                  page: result.page + 1,
                })}
              />
              {matchBox && (
                <div
                  className={styles.matchBox}
                  style={{
                    left: `${matchBox.left}%`,
                    top: `${matchBox.top}%`,
                    width: `${matchBox.width}%`,
                    height: `${matchBox.height}%`,
                  }}
                />
              )}
            </>
          ) : (
            <div className={styles.placeholder}>
              {isError
                ? t('messageSearch.imageError')
                : visible && gallery
                ? t('messageSearch.invalidPage')
                : t('viewer.loading')}
            </div>
          )}
        </div>

        <div className={styles.overlay}>
          <button type="button" className={styles.articleBtn} onClick={openInfoDialog}>
            #{result.articleId}
          </button>
          {' · '}
          <button type="button" className={styles.pageBtn} onClick={openPageThumbnails}>
            p{result.page + 1}
          </button>
        </div>
      </div>

      {showInfoDialog && article && (
        <ArticleInfoDialog article={article} onClose={() => setShowInfoDialog(false)} />
      )}
      {showPageThumbnails && gallery && (
        <PageThumbnailDialog
          thumbnailUrls={thumbnailUrls}
          currentPage={result.page}
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
