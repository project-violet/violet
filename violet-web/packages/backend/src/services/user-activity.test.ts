import assert from 'node:assert/strict';
import { test } from 'node:test';
import Database from 'better-sqlite3';
import { getUserActivity } from './user-activity.js';

test('aggregates user activity by local calendar day and type', () => {
  const db = new Database(':memory:');
  db.exec(`
    CREATE TABLE ArticleReadLog (Id INTEGER, Article TEXT, DateTimeStart TEXT, DateTimeEnd TEXT, LastPage INTEGER);
    CREATE TABLE BookmarkArticle (Id INTEGER, Article TEXT, DateTime TEXT);
    CREATE TABLE BookmarkCropImage (Id INTEGER, Article INTEGER, DateTime TEXT);
    CREATE TABLE Download (Id INTEGER, Article TEXT, DateTime TEXT, Status TEXT);

    INSERT INTO ArticleReadLog VALUES
      (1, '10', '2026-07-10T08:00:00.000Z', '2026-07-10T08:10:00.000Z', 9),
      (2, '10', '2026-07-10T09:00:00.000Z', '2026-07-10T09:05:00.000Z', 4),
      (3, '20', '2026-07-11T08:00:00.000Z', NULL, 0);
    INSERT INTO BookmarkArticle VALUES (1, '10', '2026-07-10T10:00:00.000Z');
    INSERT INTO BookmarkCropImage VALUES (1, 20, '2026-07-11 11:00:00');
    INSERT INTO Download VALUES
      (1, '30', '2026-07-11T12:00:00.000Z', 'completed'),
      (2, '40', '2026-07-11T13:00:00.000Z', 'failed');
  `);

  const result = getUserActivity(db);

  assert.deepEqual(result.totals, {
    reads: 3,
    bookmarks: 1,
    crops: 1,
    downloads: 2,
    total: 7,
    uniqueArticles: 4,
  });
  assert.deepEqual(result.days, [
    { date: '2026-07-10', reads: 2, bookmarks: 1, crops: 0, downloads: 0, total: 3 },
    { date: '2026-07-11', reads: 1, bookmarks: 0, crops: 1, downloads: 2, total: 4 },
  ]);
  assert.equal(result.firstActivityAt, '2026-07-10T08:00:00.000Z');
  assert.equal(result.lastActivityAt, '2026-07-11T13:00:00.000Z');
  assert.deepEqual(result.topArticles.slice(0, 3), [
    { articleId: '10', reads: 2, bookmarks: 1, crops: 0, downloads: 0, total: 3, recordedSeconds: 900, timedSessions: 2, averageSessionSeconds: 450, maxSessionSeconds: 600, secondsPerPageEstimate: 60 },
    { articleId: '20', reads: 1, bookmarks: 0, crops: 1, downloads: 0, total: 2, recordedSeconds: 0, timedSessions: 0, averageSessionSeconds: 0, maxSessionSeconds: 0, secondsPerPageEstimate: 0 },
    { articleId: '30', reads: 0, bookmarks: 0, crops: 0, downloads: 1, total: 1, recordedSeconds: 0, timedSessions: 0, averageSessionSeconds: 0, maxSessionSeconds: 0, secondsPerPageEstimate: 0 },
  ]);
  assert.deepEqual(result.recent.slice(0, 2).map(({ type, articleId }) => ({ type, articleId })), [
    { type: 'download', articleId: '40' },
    { type: 'download', articleId: '30' },
  ]);
  db.close();
});

test('returns an empty dashboard when user.db has no activity', () => {
  const db = new Database(':memory:');
  db.exec(`
    CREATE TABLE ArticleReadLog (Id INTEGER, Article TEXT, DateTimeStart TEXT, DateTimeEnd TEXT, LastPage INTEGER);
    CREATE TABLE BookmarkArticle (Id INTEGER, Article TEXT, DateTime TEXT);
    CREATE TABLE BookmarkCropImage (Id INTEGER, Article INTEGER, DateTime TEXT);
    CREATE TABLE Download (Id INTEGER, Article TEXT, DateTime TEXT, Status TEXT);
  `);

  const result = getUserActivity(db);
  assert.equal(result.totals.total, 0);
  assert.deepEqual(result.days, []);
  assert.deepEqual(result.recent, []);
  assert.deepEqual(result.topArticles, []);
  assert.equal(result.firstActivityAt, null);
  assert.equal(result.lastActivityAt, null);
  db.close();
});
