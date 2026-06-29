import { useNavigate } from 'react-router';
import { useTranslation } from 'react-i18next';
import { Download, BookOpen } from 'lucide-react';
import Markdown from 'react-markdown';
import type { Article } from '@violet-web/shared';
import { parsePipeTags, parseTagTuples, ticksToDate } from '@violet-web/shared';
import { LazyImage } from '../common/LazyImage';
import { useThumbnail } from '../../hooks/useThumbnail';
import { useIsBookmarked, useToggleBookmark } from '../../hooks/useBookmarks';
import { useStartDownload, useIsDownloaded } from '../../hooks/useDownloads';
import { useTagTranslation } from '../../hooks/useTagTranslation';
import { useTagCounts } from '../../hooks/useTagCounts';
import { useArticleSummary } from '../../hooks/useArticleSummary';
import { useAppStore } from '../../stores/app-store';
import { useSearchDialogStore } from '../../stores/search-dialog-store';
import styles from './ArticleInfoDialog.module.css';

interface ArticleInfoDialogProps {
  article: Article;
  onClose: () => void;
}

const TAG_ORDER: Record<string, number> = { female: 0, male: 1, tag: 2, '': 2 };

function getTagOrder(ns: string): number {
  return TAG_ORDER[ns] ?? 3;
}

export function ArticleInfoDialog({ article, onClose }: ArticleInfoDialogProps) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const tagClickAction = useAppStore((s) => s.tagClickAction);
  const openSearchDialog = useSearchDialogStore((s) => s.open);
  const { data: thumbnailUrl } = useThumbnail(article.Id);
  const { data: isBookmarked } = useIsBookmarked(String(article.Id));
  const toggleBookmark = useToggleBookmark();
  const startDownload = useStartDownload();
  const { data: isDownloaded } = useIsDownloaded(String(article.Id));
  const { translateTag } = useTagTranslation();
  const tagCounts = useTagCounts();
  const { data: summary } = useArticleSummary(article.Id);

  const artists = parsePipeTags(article.Artists);
  const groups = parsePipeTags(article.Groups);
  const series = parsePipeTags(article.Series);
  const characters = parsePipeTags(article.Characters);
  const language = article.Language ?? '';
  const tags = parseTagTuples(article.Tags)
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
    });

  const handleBookmarkClick = () => {
    toggleBookmark.mutate({ articleId: String(article.Id), isBookmarked: !!isBookmarked });
  };

  const handleDownloadClick = () => {
    startDownload.mutate(String(article.Id));
  };

  const handleViewerClick = () => {
    navigate(`/viewer/${article.Id}`);
    onClose();
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
      onClose();
    }
  };

  return (
    <div className={styles.overlay} onClick={onClose}>
      <div className={styles.dialog} onClick={(e) => e.stopPropagation()}>
        <div className={styles.body}>
          <div className={styles.thumbnail}>
            {thumbnailUrl ? (
              <LazyImage src={thumbnailUrl} alt={article.Title} className={styles.thumbnailImage} />
            ) : (
              <div className={styles.noImage}>{t('article.noImage')}</div>
            )}
          </div>

          <div className={styles.details}>
            <div className={styles.title}>{article.Title}</div>
            <span className={styles.articleId}>#{article.Id}</span>

            <div className={styles.meta}>
              {artists.length > 0 && (
                <div className={styles.field}>
                  <span className={styles.label}>Artist</span>
                  <span className={styles.value}>
                    {artists.map((a, i) => (
                      <span key={a}>
                        {i > 0 && ', '}
                        <span className={styles.clickable} onClick={handleSearchClick('artist', a)}>{a}</span>
                      </span>
                    ))}
                  </span>
                </div>
              )}
              {language && (
                <div className={styles.field}>
                  <span className={styles.label}>Language</span>
                  <span className={styles.value}>{language}</span>
                </div>
              )}
              {article.Type && (
                <div className={styles.field}>
                  <span className={styles.label}>Type</span>
                  <span className={styles.value}>{article.Type}</span>
                </div>
              )}
              {article.Files != null && (
                <div className={styles.field}>
                  <span className={styles.label}>Pages</span>
                  <span className={styles.value}>{article.Files}</span>
                </div>
              )}
              {groups.length > 0 && (
                <div className={styles.field}>
                  <span className={styles.label}>Group</span>
                  <span className={styles.value}>
                    {groups.map((g, i) => (
                      <span key={g}>
                        {i > 0 && ', '}
                        <span className={styles.clickable} onClick={handleSearchClick('group', g)}>{g}</span>
                      </span>
                    ))}
                  </span>
                </div>
              )}
              {series.length > 0 && (
                <div className={styles.field}>
                  <span className={styles.label}>Series</span>
                  <span className={styles.value}>
                    {series.map((s, i) => (
                      <span key={s}>
                        {i > 0 && ', '}
                        <span className={styles.clickable} onClick={handleSearchClick('series', s)}>{s}</span>
                      </span>
                    ))}
                  </span>
                </div>
              )}
              {characters.length > 0 && (
                <div className={styles.field}>
                  <span className={styles.label}>Character</span>
                  <span className={styles.value}>
                    {characters.map((c, i) => (
                      <span key={c}>
                        {i > 0 && ', '}
                        <span className={styles.clickable} onClick={handleSearchClick('character', c)}>{c}</span>
                      </span>
                    ))}
                  </span>
                </div>
              )}
              {article.Published != null && (
                <div className={styles.field}>
                  <span className={styles.label}>Published</span>
                  <span className={styles.value}>
                    {(typeof article.Published === 'number'
                      ? ticksToDate(article.Published)
                      : new Date(article.Published)
                    ).toLocaleDateString()}
                  </span>
                </div>
              )}
            </div>

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

            <div className={styles.actions}>
              <button
                className={`${styles.actionBtn} ${styles.bookmarkBtn} ${isBookmarked ? styles.bookmarked : ''}`}
                onClick={handleBookmarkClick}
                disabled={toggleBookmark.isPending}
              >
                {isBookmarked ? '★' : '☆'}
              </button>
              <button
                className={`${styles.actionBtn} ${styles.downloadBtn} ${isDownloaded ? styles.downloaded : ''}`}
                onClick={handleDownloadClick}
                disabled={startDownload.isPending}
              >
                <Download size={16} />
              </button>
              <button
                className={`${styles.actionBtn} ${styles.viewerBtn}`}
                onClick={handleViewerClick}
              >
                <BookOpen size={16} />
              </button>
            </div>
          </div>
        </div>

        {summary && (
          <div className={styles.summary}>
            <Markdown>{summary}</Markdown>
          </div>
        )}

        <div className={styles.actionsMobile}>
          <button
            className={`${styles.actionBtn} ${styles.bookmarkBtn} ${isBookmarked ? styles.bookmarked : ''}`}
            onClick={handleBookmarkClick}
            disabled={toggleBookmark.isPending}
          >
            {isBookmarked ? '★' : '☆'}
          </button>
          <button
            className={`${styles.actionBtn} ${styles.downloadBtn}`}
            onClick={handleDownloadClick}
            disabled={startDownload.isPending}
          >
            <Download size={16} />
          </button>
          <button
            className={`${styles.actionBtn} ${styles.viewerBtn}`}
            onClick={handleViewerClick}
          >
            <BookOpen size={16} />
          </button>
        </div>

      </div>
    </div>
  );
}
