import type Database from 'better-sqlite3';

export interface HistoryDateEntry {
  articleId: string;
  date: string;
}

export function getLatestHistoryEntries(db: Database.Database): HistoryDateEntry[] {
  const rows = db.prepare(`
    SELECT Article, DateTimeStart FROM (
      SELECT Article, DateTimeStart, Id,
             ROW_NUMBER() OVER (PARTITION BY Article ORDER BY Id DESC) AS rn
      FROM ArticleReadLog
    ) WHERE rn = 1
    ORDER BY Id DESC
  `).all() as Array<{ Article: string; DateTimeStart: string }>;
  return rows.map((row) => ({ articleId: row.Article, date: row.DateTimeStart }));
}
