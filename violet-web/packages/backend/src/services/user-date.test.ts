import assert from 'node:assert/strict';
import { test } from 'node:test';
import Database from 'better-sqlite3';
import { getLatestHistoryEntries } from './user-date.js';

test('returns the latest read date for each article', () => {
  const db = new Database(':memory:');
  db.exec('CREATE TABLE ArticleReadLog (Id INTEGER, Article TEXT, DateTimeStart TEXT)');
  db.exec(`
    INSERT INTO ArticleReadLog VALUES
      (1, '10', '2026-01-01T00:00:00.000Z'),
      (2, '10', '2026-02-01T00:00:00.000Z'),
      (3, '20', '2026-01-15T00:00:00.000Z')
  `);

  assert.deepEqual(getLatestHistoryEntries(db), [
    { articleId: '20', date: '2026-01-15T00:00:00.000Z' },
    { articleId: '10', date: '2026-02-01T00:00:00.000Z' },
  ]);
  db.close();
});
