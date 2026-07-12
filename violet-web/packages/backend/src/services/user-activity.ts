import type Database from 'better-sqlite3';

export type ActivityType = 'read' | 'bookmark' | 'crop' | 'download';

export interface ActivityDay {
  date: string;
  reads: number;
  bookmarks: number;
  crops: number;
  downloads: number;
  total: number;
}

export interface UserActivityResult {
  totals: {
    reads: number;
    bookmarks: number;
    crops: number;
    downloads: number;
    total: number;
    uniqueArticles: number;
  };
  days: ActivityDay[];
  recent: Array<{ type: ActivityType; articleId: string; date: string }>;
  topArticles: Array<{
    articleId: string;
    reads: number;
    bookmarks: number;
    crops: number;
    downloads: number;
    total: number;
    recordedSeconds: number;
    timedSessions: number;
    averageSessionSeconds: number;
    maxSessionSeconds: number;
    secondsPerPageEstimate: number;
  }>;
  firstActivityAt: string | null;
  lastActivityAt: string | null;
}

interface ActivityRow {
  type: ActivityType;
  articleId: string;
  date: string;
  durationSeconds: number | null;
  lastPage: number | null;
}

export function getUserActivity(db: Database.Database): UserActivityResult {
  const rows = db.prepare(`
    SELECT type, CAST(articleId AS TEXT) AS articleId, date, durationSeconds, lastPage FROM (
      SELECT 'read' AS type, Article AS articleId, DateTimeStart AS date,
             CASE
               WHEN DateTimeEnd IS NOT NULL
                AND (julianday(DateTimeEnd) - julianday(DateTimeStart)) * 86400 BETWEEN 0 AND 14400
               THEN (julianday(DateTimeEnd) - julianday(DateTimeStart)) * 86400
               ELSE NULL
             END AS durationSeconds,
             LastPage AS lastPage
      FROM ArticleReadLog
      UNION ALL
      SELECT 'bookmark', Article, DateTime, NULL, NULL FROM BookmarkArticle
      UNION ALL
      SELECT 'crop', Article, DateTime, NULL, NULL FROM BookmarkCropImage
      UNION ALL
      SELECT 'download', Article, DateTime, NULL, NULL FROM Download
    )
    WHERE date IS NOT NULL AND date != ''
    ORDER BY datetime(date) DESC, date DESC
  `).all() as ActivityRow[];

  const days = new Map<string, ActivityDay>();
  const articleActivity = new Map<string, UserActivityResult['topArticles'][number] & { estimatedPages: number }>();
  const articles = new Set<string>();
  const totals = { reads: 0, bookmarks: 0, crops: 0, downloads: 0, total: rows.length, uniqueArticles: 0 };

  for (const row of rows) {
    const date = row.date.slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) continue;
    const day = days.get(date) ?? { date, reads: 0, bookmarks: 0, crops: 0, downloads: 0, total: 0 };
    if (row.type === 'read') totals.reads += 1, day.reads += 1;
    if (row.type === 'bookmark') totals.bookmarks += 1, day.bookmarks += 1;
    if (row.type === 'crop') totals.crops += 1, day.crops += 1;
    if (row.type === 'download') totals.downloads += 1, day.downloads += 1;
    day.total += 1;
    days.set(date, day);
    articles.add(row.articleId);
    const article = articleActivity.get(row.articleId) ?? {
      articleId: row.articleId, reads: 0, bookmarks: 0, crops: 0, downloads: 0, total: 0,
      recordedSeconds: 0, timedSessions: 0, averageSessionSeconds: 0, maxSessionSeconds: 0,
      secondsPerPageEstimate: 0, estimatedPages: 0,
    };
    if (row.type === 'read') article.reads += 1;
    if (row.type === 'bookmark') article.bookmarks += 1;
    if (row.type === 'crop') article.crops += 1;
    if (row.type === 'download') article.downloads += 1;
    article.total += 1;
    if (row.type === 'read' && row.durationSeconds != null) {
      article.recordedSeconds += row.durationSeconds;
      article.timedSessions += 1;
      article.maxSessionSeconds = Math.max(article.maxSessionSeconds, row.durationSeconds);
      if (row.lastPage != null && row.lastPage >= 0) article.estimatedPages += row.lastPage + 1;
    }
    articleActivity.set(row.articleId, article);
  }

  totals.uniqueArticles = articles.size;
  const chronological = [...days.values()].sort((a, b) => a.date.localeCompare(b.date));
  const validRows = rows.filter((row) => /^\d{4}-\d{2}-\d{2}/.test(row.date));

  return {
    totals,
    days: chronological,
    recent: validRows.slice(0, 12),
    topArticles: [...articleActivity.values()].map(({ estimatedPages, ...article }) => ({
      ...article,
      recordedSeconds: Math.round(article.recordedSeconds),
      averageSessionSeconds: article.timedSessions ? Math.round(article.recordedSeconds / article.timedSessions) : 0,
      maxSessionSeconds: Math.round(article.maxSessionSeconds),
      secondsPerPageEstimate: estimatedPages ? Math.round(article.recordedSeconds / estimatedPages) : 0,
    })).sort((a, b) => b.total - a.total || b.reads - a.reads || Number(a.articleId) - Number(b.articleId)),
    firstActivityAt: validRows.length ? validRows[validRows.length - 1].date : null,
    lastActivityAt: validRows.length ? validRows[0].date : null,
  };
}
