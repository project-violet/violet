import { Router } from 'express';
import { unzipSync, strFromU8 } from 'fflate';
import { getUserDb } from '../services/user-db.js';

const DAILY_ZIP_URL =
  'https://github.com/project-violet/violet/raw/refs/heads/dev/violet/assets/daily.zip';

export const bookmarksRouter = Router();

// --- Groups ---

bookmarksRouter.get('/groups', (_req, res) => {
  const db = getUserDb();
  const groups = db.prepare('SELECT * FROM BookmarkGroup ORDER BY Gorder ASC').all();
  res.json(groups);
});

bookmarksRouter.post('/groups', (req, res) => {
  const { Name, Description, Color } = req.body;
  const db = getUserDb();
  const maxOrder = db
    .prepare('SELECT COALESCE(MAX(Gorder), 0) as m FROM BookmarkGroup')
    .get() as { m: number };
  const result = db
    .prepare(
      'INSERT INTO BookmarkGroup (Name, DateTime, Description, Color, Gorder) VALUES (?, ?, ?, ?, ?)',
    )
    .run(Name, new Date().toISOString(), Description ?? null, Color ?? null, maxOrder.m + 1);
  res.json({ Id: result.lastInsertRowid });
});

bookmarksRouter.delete('/groups/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const db = getUserDb();
  db.prepare('DELETE FROM BookmarkArticle WHERE GroupId = ?').run(id);
  db.prepare('DELETE FROM BookmarkArtist WHERE GroupId = ?').run(id);
  db.prepare('DELETE FROM BookmarkGroup WHERE Id = ?').run(id);
  res.json({ ok: true });
});

// --- Articles ---

bookmarksRouter.get('/articles', (req, res) => {
  const groupId = req.query.groupId ? parseInt(req.query.groupId as string) : undefined;
  const db = getUserDb();
  const sql = groupId !== undefined
    ? 'SELECT * FROM BookmarkArticle WHERE GroupId = ? ORDER BY Id DESC'
    : 'SELECT * FROM BookmarkArticle ORDER BY Id DESC';
  const articles = groupId !== undefined
    ? db.prepare(sql).all(groupId)
    : db.prepare(sql).all();
  res.json(articles);
});

bookmarksRouter.post('/articles', (req, res) => {
  const { Article, GroupId } = req.body;
  const gid = GroupId ?? 1;
  const db = getUserDb();
  const result = db
    .prepare('INSERT INTO BookmarkArticle (Article, DateTime, GroupId) VALUES (?, ?, ?)')
    .run(Article, new Date().toISOString(), gid);
  res.json({ Id: result.lastInsertRowid });
});

bookmarksRouter.delete('/articles/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const db = getUserDb();
  db.prepare('DELETE FROM BookmarkArticle WHERE Id = ?').run(id);
  res.json({ ok: true });
});

bookmarksRouter.get('/articles/check/:articleId', (req, res) => {
  const articleId = req.params.articleId;
  const db = getUserDb();
  const row = db
    .prepare('SELECT Id FROM BookmarkArticle WHERE Article = ? LIMIT 1')
    .get(articleId);
  res.json({ bookmarked: !!row });
});

// --- Artists ---

bookmarksRouter.get('/artists', (req, res) => {
  const groupId = req.query.groupId ? parseInt(req.query.groupId as string) : undefined;
  const db = getUserDb();
  const sql = groupId !== undefined
    ? 'SELECT * FROM BookmarkArtist WHERE GroupId = ? ORDER BY Id DESC'
    : 'SELECT * FROM BookmarkArtist ORDER BY Id DESC';
  const artists = groupId !== undefined
    ? db.prepare(sql).all(groupId)
    : db.prepare(sql).all();
  res.json(artists);
});

bookmarksRouter.post('/artists', (req, res) => {
  const { Artist, IsGroup, GroupId } = req.body;
  const gid = GroupId ?? 1;
  const db = getUserDb();
  const result = db
    .prepare('INSERT INTO BookmarkArtist (Artist, IsGroup, DateTime, GroupId) VALUES (?, ?, ?, ?)')
    .run(Artist, IsGroup ?? 0, new Date().toISOString(), gid);
  res.json({ Id: result.lastInsertRowid });
});

bookmarksRouter.delete('/artists/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const db = getUserDb();
  db.prepare('DELETE FROM BookmarkArtist WHERE Id = ?').run(id);
  res.json({ ok: true });
});

// --- Crop Images ---

// User crop bookmarks (from daily.zip) — must be before /crops/:id
let userCropCache: { data: unknown[]; fetchedAt: number } | null = null;
const USER_CROP_CACHE_TTL = 10 * 60 * 1000; // 10 min

bookmarksRouter.get('/crops/user', async (_req, res, next) => {
  try {
    if (userCropCache && Date.now() - userCropCache.fetchedAt < USER_CROP_CACHE_TTL) {
      res.json(userCropCache.data);
      return;
    }

    const response = await fetch(DAILY_ZIP_URL);
    if (!response.ok) {
      res.status(502).json({ error: `Failed to fetch daily.zip: ${response.status}` });
      return;
    }

    const buf = new Uint8Array(await response.arrayBuffer());
    const files = unzipSync(buf);

    const entry = Object.entries(files).find(([name]) =>
      name.endsWith('crop-bookmarks.json'),
    );
    if (!entry) {
      res.status(404).json({ error: 'crop-bookmarks.json not found in zip' });
      return;
    }

    const data = JSON.parse(strFromU8(entry[1]));
    userCropCache = { data, fetchedAt: Date.now() };
    res.json(data);
  } catch (err) {
    next(err);
  }
});

bookmarksRouter.get('/crops', (_req, res) => {
  const db = getUserDb();
  const crops = db.prepare('SELECT * FROM BookmarkCropImage ORDER BY Id DESC').all();
  res.json(crops);
});

bookmarksRouter.post('/crops', (req, res) => {
  const { Article, Page, Area, AspectRatio } = req.body;
  const db = getUserDb();
  const nextId = (
    db.prepare('SELECT COALESCE(MAX(Id), 0) + 1 AS nextId FROM BookmarkCropImage').get() as { nextId: number }
  ).nextId;
  const result = db
    .prepare(
      'INSERT INTO BookmarkCropImage (Id, Article, Page, Area, AspectRatio, DateTime) VALUES (?, ?, ?, ?, ?, ?)',
    )
    .run(nextId, Article, Page, Area, AspectRatio, new Date().toISOString().replace('T', ' ').replace('Z', ''));
  res.json({ Id: result.lastInsertRowid });
});

bookmarksRouter.delete('/crops/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const db = getUserDb();
  db.prepare('DELETE FROM BookmarkCropImage WHERE Id = ?').run(id);
  res.json({ ok: true });
});
