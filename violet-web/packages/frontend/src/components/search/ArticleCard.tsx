import { useState } from 'react';
import { useNavigate } from 'react-router';
import { useTranslation } from 'react-i18next';
import { Download, Trash2, RotateCw } from 'lucide-react';
import type { Article } from '@violet-web/shared';
import { parsePipeTags, parseTagTuples, ticksToDate } from '@violet-web/shared';
import { LazyImage } from '../common/LazyImage';
import { BookmarkToggleButton } from '../common/BookmarkToggleButton';
import { useCachedThumbnail } from '../../hooks/useCachedThumbnail';
import { useStartDownload, useRetryDownload, useDeleteDownload, useIsDownloaded } from '../../hooks/useDownloads';
import { useDownloadProgress, useIsDownloadsPage } from '../../contexts/DownloadProgressContext';
import { useTagTranslation } from '../../hooks/useTagTranslation';
import { useTagCounts } from '../../hooks/useTagCounts';
import { useImageList } from '../../hooks/useImageList';
import { getProxyImageUrl } from '../../api/proxy';
import { ArticleInfoDialog } from './ArticleInfoDialog';
import { PageThumbnailDialog } from '../viewer/PageThumbnailDialog';
import { useAppStore } from '../../stores/app-store';
import { useSearchDialogStore } from '../../stores/search-dialog-store';
import type { ViewMode } from '../../stores/app-store';
import styles from './ArticleCard.module.css';

interface ArticleCardProps {
  article: Article;
  viewMode?: ViewMode;
  aiScore?: number;
  aiDescription?: string;
  rank?: number;
  viewCount?: number;
}

const TAG_ORDER: Record<string, number> = { female: 0, male: 1, tag: 2, '': 2 };

function getTagOrder(ns: string): number {
  return TAG_ORDER[ns] ?? 3;
}

export function ArticleCard({ article, viewMode = 'grid', aiScore, aiDescription, rank, viewCount }: ArticleCardProps) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { src: thumbnailSrc, onLoadSuccess: onThumbnailLoad } = useCachedThumbnail(article.Id);
  const startDownload = useStartDownload();
  const retryDownload = useRetryDownload();
  const deleteDownload = useDeleteDownload();
  const isDownloadsPage = useIsDownloadsPage();
  const { data: isDownloaded } = useIsDownloaded(String(article.Id));
  const downloadRecord = useDownloadProgress(String(article.Id));
  const { translateTag } = useTagTranslation();
  const tagCounts = useTagCounts();
  const tagClickAction = useAppStore((s) => s.tagClickAction);
  const openSearchDialog = useSearchDialogStore((s) => s.open);
  const [showInfoDialog, setShowInfoDialog] = useState(false);
  const [showPageThumbnails, setShowPageThumbnails] = useState(false);
  const { data: imageList } = useImageList(showPageThumbnails ? article.Id : 0);

  const artists = parsePipeTags(article.Artists);
  const language = article.Language ?? '';

  const handleDownloadClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    startDownload.mutate(String(article.Id));
  };

  const handleRetryDownload = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (downloadRecord) {
      retryDownload.mutate(downloadRecord.Id);
    }
  };

  const handleDeleteDownload = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (downloadRecord) {
      deleteDownload.mutate(downloadRecord.Id);
    }
  };

  const handleSearchClick = (category: string, value: string) => (e: React.MouseEvent) => {
    e.stopPropagation();
    const encoded = value.replace(/ /g, '_');
    if (e.ctrlKey || e.metaKey) {
      window.open(`/?q=${category}:${encoded}`, '_blank');
    } else if (tagClickAction === 'dialog') {
      openSearchDialog(`${category}:${encoded}`);
    } else {
      navigate(`/?q=${category}:${encoded}`);
    }
  };

  const handlePageCountClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    setShowPageThumbnails(true);
  };

  const handlePageSelect = (pageIndex: number) => {
    // pageIndex is 0-based, convert to 1-based for URL
    navigate(`/viewer/${article.Id}?page=${pageIndex + 1}`);
  };

  const isDetail = viewMode === 'detail';

  const groups = isDetail ? parsePipeTags(article.Groups) : [];
  const series = isDetail ? parsePipeTags(article.Series) : [];
  const tags = isDetail
    ? parseTagTuples(article.Tags)
        .filter((t) => ['female', 'male', 'tag', ''].includes(t.namespace))
        .sort((a, b) => {
          const orderDiff = getTagOrder(a.namespace) - getTagOrder(b.namespace);
          if (orderDiff !== 0) return orderDiff;
          if (tagCounts) {
            const countA = tagCounts[`${a.namespace}:${a.tag}`] ?? 0;
            const countB = tagCounts[`${b.namespace}:${b.tag}`] ?? 0;
            return countB - countA;
          }
          return a.tag.localeCompare(b.tag);
        })
    : [];

  return (
    <>
      <div
        className={`${styles.card} bookmark-hover-scope ${isDetail ? styles.detailCard : ''}`}
        onClick={(e) => {
          if (e.shiftKey) { e.preventDefault(); setShowPageThumbnails(true); }
          else navigate(`/viewer/${article.Id}`);
        }}
      >
        <div className={styles.imageWrapper}>
          {thumbnailSrc ? (
            <LazyImage src={thumbnailSrc} alt={article.Title} className={styles.image} onLoad={onThumbnailLoad} />
          ) : (
            <div className={styles.noImage}>{t('article.noImage')}</div>
          )}
          {isDownloadsPage ? (
            <button
              className={`${styles.downloadBtn} ${styles.deleteBtn}`}
              onClick={handleDeleteDownload}
              disabled={deleteDownload.isPending}
              aria-label={t('downloads.delete')}
            >
              <Trash2 size={14} />
            </button>
          ) : (
            <button
              className={`${styles.downloadBtn} ${isDownloaded ? styles.downloaded : ''}`}
              onClick={handleDownloadClick}
              disabled={startDownload.isPending}
              aria-label={t('downloads.heading')}
            >
              <Download size={14} />
            </button>
          )}
          <BookmarkToggleButton articleId={article.Id} />
          {article.Files != null && (
            <span
              className={`${styles.pageCount} ${styles.clickable}`}
              onClick={handlePageCountClick}
            >
              {article.Files}P
            </span>
          )}
          {rank != null && (
            <span className={styles.rankBadge}>
              #{rank}{viewCount != null && ` (${viewCount.toLocaleString()})`}
            </span>
          )}
          {downloadRecord && downloadRecord.Status === 'downloading' && (() => {
            const pct = downloadRecord.TotalPages > 0
              ? downloadRecord.DownloadedPages / downloadRecord.TotalPages
              : 0;
            const r = 36;
            const circ = 2 * Math.PI * r;
            const offset = circ * (1 - pct);
            return (
              <div className={styles.progressOverlay}>
                <svg className={styles.progressRing} viewBox="0 0 80 80">
                  <circle className={styles.progressRingBg} cx="40" cy="40" r={r} />
                  <circle
                    className={styles.progressRingFill}
                    cx="40" cy="40" r={r}
                    strokeDasharray={circ}
                    strokeDashoffset={offset}
                  />
                </svg>
                <div className={styles.progressText}>
                  {downloadRecord.DownloadedPages}/{downloadRecord.TotalPages}
                </div>
              </div>
            );
          })()}
          {downloadRecord && downloadRecord.Status === 'failed' && (
            <div className={styles.failedOverlay}>
              <button
                className={styles.retryBtn}
                onClick={handleRetryDownload}
                disabled={retryDownload.isPending}
              >
                <RotateCw size={20} />
              </button>
              <div className={styles.failedText}>{t('downloads.retry')}</div>
              {downloadRecord.ErrorMessage && (
                <div className={styles.failedError}>{downloadRecord.ErrorMessage}</div>
              )}
            </div>
          )}
        </div>
        <div className={styles.info}>
          <div className={styles.title}>{article.Title}</div>
          <div className={styles.meta}>
            <span
              className={`${styles.articleId} ${styles.clickable}`}
              onClick={(e) => { e.stopPropagation(); setShowInfoDialog(true); }}
            >#{article.Id}</span>
            {artists.length > 0 && (
              <span>
                {isDetail && <span className={styles.detailLabel}>Artist</span>}
                {artists.map((a, i) => (
                  <span key={a}>
                    {i > 0 && ', '}
                    <span className={styles.clickable} onClick={handleSearchClick('artist', a)}>{a}</span>
                  </span>
                ))}
              </span>
            )}
            {language && (
              <span className={styles.lang}>{isDetail && <span className={styles.detailLabel}>Lang</span>}{language}</span>
            )}
          </div>

          {aiScore != null && (
            <div className={styles.aiInfo}>
              <span className={styles.aiScoreBadge}>{Math.round(aiScore * 100)}%</span>
              {aiDescription && (
                <p className={styles.aiDescription}>{aiDescription}</p>
              )}
            </div>
          )}

          {isDetail && (
            <div className={styles.detailInfo}>
              {groups.length > 0 && (
                <div className={styles.detailRow}>
                  <span className={styles.detailLabel}>Group</span>
                  <span>{groups.map((g, i) => (
                    <span key={g}>
                      {i > 0 && ', '}
                      <span className={styles.clickable} onClick={handleSearchClick('group', g)}>{g}</span>
                    </span>
                  ))}</span>
                </div>
              )}
              {series.length > 0 && (
                <div className={styles.detailRow}>
                  <span className={styles.detailLabel}>Series</span>
                  <span>{series.map((s, i) => (
                    <span key={s}>
                      {i > 0 && ', '}
                      <span className={styles.clickable} onClick={handleSearchClick('series', s)}>{s}</span>
                    </span>
                  ))}</span>
                </div>
              )}
              {article.Published != null && (
                <div className={styles.detailRow}>
                  <span className={styles.detailLabel}>Date</span>
                  <span>{(typeof article.Published === 'number'
                    ? ticksToDate(article.Published)
                    : new Date(article.Published)
                  ).toLocaleDateString()}</span>
                </div>
              )}
              {tags.length > 0 && (
                <div className={styles.tagList}>
                  {tags.map((tag) => {
                    const koTag = translateTag(tag.namespace, tag.tag.replace(/_/g, ' '));
                    const category = tag.namespace || 'tag';
                    return (
                      <span
                        key={`${tag.namespace}:${tag.tag}`}
                        className={`${styles.tagChip} ${
                          tag.namespace === 'female'
                            ? styles.tagFemale
                            : tag.namespace === 'male'
                              ? styles.tagMale
                              : styles.tagGeneral
                        }`}
                        onClick={handleSearchClick(category, tag.tag)}
                      >
                        {koTag ?? tag.tag.replace(/_/g, ' ')}
                      </span>
                    );
                  })}
                </div>
              )}
            </div>
          )}
        </div>
      </div>
      {showInfoDialog && (
        <ArticleInfoDialog article={article} onClose={() => setShowInfoDialog(false)} />
      )}
      {showPageThumbnails && imageList && (
        <PageThumbnailDialog
          thumbnailUrls={(imageList.smallThumbnails ?? []).map((url) =>
            getProxyImageUrl(url, `https://hitomi.la/reader/${article.Id}.html`),
          )}
          currentPage={0}
          totalPages={article.Files ?? 0}
          twoPageMode={false}
          coverPageMode="normal"
          onPageSelect={handlePageSelect}
          onClose={() => setShowPageThumbnails(false)}
        />
      )}
    </>
  );
}
