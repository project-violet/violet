import assert from 'node:assert/strict';
import { test } from 'node:test';
import Database from 'better-sqlite3';
import {
  normalizedPublishedSql,
  parseDateBounds,
  getDateDistribution,
} from './publication-date.js';

test('normalizes ticks and text while excluding invalid integers', () => {
  const db = new Database(':memory:');
  db.exec('CREATE TABLE works (Published);');
  db.prepare('INSERT INTO works VALUES (?)').run(638712864000000000n);
  db.prepare('INSERT INTO works VALUES (?)').run('2025-01-01 00:00:00');
  db.prepare('INSERT INTO works VALUES (?)').run(2026);

  const rows = db.prepare(`SELECT ${normalizedPublishedSql('Published')} AS publishedAt FROM works`).all() as Array<{ publishedAt: string | null }>;
  assert.equal(rows[0].publishedAt, '2025-01-01 00:00:00');
  assert.equal(rows[1].publishedAt, '2025-01-01 00:00:00');
  assert.equal(rows[2].publishedAt, null);
});

test('parses inclusive ISO day bounds and rejects reversed bounds', () => {
  assert.deepEqual(parseDateBounds('2020-01-01', '2021-12-31'), {
    from: '2020-01-01 00:00:00',
    toExclusive: '2022-01-01 00:00:00',
  });
  assert.throws(() => parseDateBounds('2022-01-01', '2021-12-31'), /before or equal/);
  assert.throws(() => parseDateBounds('2025-02-30', undefined), /valid calendar/);
});

test('builds a continuous distribution and counts invalid rows', () => {
  const db = new Database(':memory:');
  db.exec(`
    CREATE TABLE HitomiColumnModel (Id INTEGER PRIMARY KEY, Published, ExistOnHitomi INTEGER);
    INSERT INTO HitomiColumnModel VALUES (1, '2024-01-15 00:00:00', 1);
    INSERT INTO HitomiColumnModel VALUES (2, '2024-03-15 00:00:00', 1);
    INSERT INTO HitomiColumnModel VALUES (3, 2026, 1);
  `);

  const value = getDateDistribution(db, 'ExistOnHitomi=1', 'test');
  assert.equal(value.totalCount, 2);
  assert.equal(value.invalidCount, 1);
  assert.equal(value.unit, 'month');
  assert.deepEqual(value.buckets.map((bucket) => bucket.count), [1, 0, 1]);
});
