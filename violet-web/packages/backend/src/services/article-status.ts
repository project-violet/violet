import type Database from 'better-sqlite3';
import type { Request, Response } from 'express';

export function articleStatusHandler(getDb: () => Database.Database, kind: 'bookmark' | 'download') {
  return (req: Request, res: Response) => {
    const ids: unknown = req.body?.ids;
    if (!Array.isArray(ids) || ids.length > 200 || ids.some((id) => typeof id !== 'string' || id.length > 100)) {
      res.status(400).json({ error: 'ids must contain at most 200 article ID strings' });
      return;
    }
    const unique = [...new Set(ids as string[])];
    if (unique.length === 0) { res.json({}); return; }
    const table = kind === 'bookmark' ? 'BookmarkArticle' : 'Download';
    const condition = kind === 'download' ? " AND Status = 'completed'" : '';
    const rows = getDb().prepare(`SELECT DISTINCT Article FROM ${table} WHERE Article IN (${unique.map(() => '?').join(',')})${condition}`)
      .all(...unique) as Array<{ Article: string }>;
    const found = new Set(rows.map((row) => String(row.Article)));
    res.json(Object.fromEntries(unique.map((id) => [id, found.has(id)])));
  };
}
