import type Database from 'better-sqlite3';

export interface HistoryDateEntry {
  articleId: string;
  date: string;
}

export function getLatestHistoryEntries(db: Database.Database): HistoryDateEntry[] {
  return getLatestEntries(db, 'ArticleReadLog', 'DateTimeStart');
}

export function getLatestDownloadEntries(db: Database.Database): HistoryDateEntry[] {
  return getLatestEntries(db, 'Download', 'DateTime');
}

function getLatestEntries(
  db: Database.Database,
  table: 'ArticleReadLog' | 'Download',
  dateColumn: 'DateTimeStart' | 'DateTime',
): HistoryDateEntry[] {
  const rows = db.prepare(`
    SELECT Article, ${dateColumn} AS DateTimeStart FROM (
      SELECT Article, ${dateColumn}, Id,
             ROW_NUMBER() OVER (PARTITION BY Article ORDER BY Id DESC) AS rn
      FROM ${table}
    ) WHERE rn = 1
    ORDER BY Id DESC
  `).all() as Array<{ Article: string; DateTimeStart: string }>;
  return rows.map((row) => ({ articleId: row.Article, date: row.DateTimeStart }));
}
