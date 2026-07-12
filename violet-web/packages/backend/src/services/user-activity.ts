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
  }>;
  firstActivityAt: string | null;
  lastActivityAt: string | null;
}

interface ActivityRow {
  type: ActivityType;
  articleId: string;
  date: string;
}

export function getUserActivity(db: Database.Database): UserActivityResult {
  const rows = db.prepare(`
    SELECT type, CAST(articleId AS TEXT) AS articleId, date FROM (
      SELECT 'read' AS type, Article AS articleId, DateTimeStart AS date FROM ArticleReadLog
      UNION ALL
      SELECT 'bookmark', Article, DateTime FROM BookmarkArticle
      UNION ALL
      SELECT 'crop', Article, DateTime FROM BookmarkCropImage
      UNION ALL
      SELECT 'download', Article, DateTime FROM Download
    )
    WHERE date IS NOT NULL AND date != ''
    ORDER BY datetime(date) DESC, date DESC
  `).all() as ActivityRow[];

  const days = new Map<string, ActivityDay>();
  const articleActivity = new Map<string, UserActivityResult['topArticles'][number]>();
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
    const article = articleActivity.get(row.articleId) ?? { articleId: row.articleId, reads: 0, bookmarks: 0, crops: 0, downloads: 0, total: 0 };
    if (row.type === 'read') article.reads += 1;
    if (row.type === 'bookmark') article.bookmarks += 1;
    if (row.type === 'crop') article.crops += 1;
    if (row.type === 'download') article.downloads += 1;
    article.total += 1;
    articleActivity.set(row.articleId, article);
  }

  totals.uniqueArticles = articles.size;
  const chronological = [...days.values()].sort((a, b) => a.date.localeCompare(b.date));
  const validRows = rows.filter((row) => /^\d{4}-\d{2}-\d{2}/.test(row.date));

  return {
    totals,
    days: chronological,
    recent: validRows.slice(0, 12),
    topArticles: [...articleActivity.values()].sort((a, b) =>
      b.total - a.total || b.reads - a.reads || b.bookmarks - a.bookmarks || Number(a.articleId) - Number(b.articleId),
    ),
    firstActivityAt: validRows.length ? validRows[validRows.length - 1].date : null,
    lastActivityAt: validRows.length ? validRows[0].date : null,
  };
}
