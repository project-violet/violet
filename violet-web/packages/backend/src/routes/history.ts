import { Router } from 'express';
import { getUserDb } from '../services/user-db.js';
import { getLatestHistoryEntries } from '../services/user-date.js';

export const historyRouter = Router();

historyRouter.get('/', (req, res) => {
  const page = parseInt(req.query.page as string) || 0;
  const pageSize = Math.min(parseInt(req.query.pageSize as string) || 30, 100);
  const db = getUserDb();

  // Get unique articles with their most recent log entry
  // Using window function to get the latest entry per article
  const logs = db
    .prepare(`
      SELECT * FROM (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY Article ORDER BY Id DESC) as rn
        FROM ArticleReadLog
      ) WHERE rn = 1
      ORDER BY Id DESC
      LIMIT ? OFFSET ?
    `)
    .all(pageSize, page * pageSize);

  // Count unique articles instead of all logs
  const countRow = db
    .prepare('SELECT COUNT(DISTINCT Article) as cnt FROM ArticleReadLog')
    .get() as { cnt: number };

  res.json({ logs, totalCount: countRow.cnt, page, pageSize });
});

historyRouter.get('/ids', (_req, res) => {
  const db = getUserDb();
  const entries = getLatestHistoryEntries(db);
  res.json({ articleIds: entries.map((entry) => entry.articleId), entries });
});

historyRouter.get('/last-page/:article', (req, res) => {
  const article = req.params.article;
  const db = getUserDb();
  const row = db
    .prepare(
      `SELECT LastPage FROM ArticleReadLog
       WHERE Article = ? AND LastPage > 0
       ORDER BY Id DESC LIMIT 1`,
    )
    .get(article) as { LastPage: number } | undefined;
  res.json({ lastPage: row?.LastPage ?? null });
});

historyRouter.post('/', (req, res) => {
  const { Article, Type } = req.body;
  const db = getUserDb();
  const result = db
    .prepare(
      'INSERT INTO ArticleReadLog (Article, DateTimeStart, DateTimeEnd, LastPage, Type) VALUES (?, ?, NULL, 0, ?)',
    )
    .run(Article, new Date().toISOString(), Type ?? 0);
  res.json({ Id: result.lastInsertRowid });
});

historyRouter.patch('/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const { LastPage, DateTimeEnd } = req.body;
  const db = getUserDb();
  const end = DateTimeEnd ?? new Date().toISOString();
  db.prepare(
    'UPDATE ArticleReadLog SET LastPage = ?, DateTimeEnd = ? WHERE Id = ?',
  ).run(LastPage, end, id);
  res.json({ ok: true });
});

historyRouter.delete('/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const db = getUserDb();
  db.prepare('DELETE FROM ArticleReadLog WHERE Id = ?').run(id);
  res.json({ ok: true });
});
