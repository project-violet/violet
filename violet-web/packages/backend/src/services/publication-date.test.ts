import assert from 'node:assert/strict';
import { test } from 'node:test';
import Database from 'better-sqlite3';
import {
  normalizedPublishedSql,
  parseDateBounds,
  getDateDistribution,
} from './publication-date.js';

test('distribution preserves day/year buckets, empty counts, and connection/write isolation', () => {
  const db = new Database(':memory:');
  const other = new Database(':memory:');
  for (const connection of [db, other]) connection.exec('CREATE TABLE HitomiColumnModel (Published)');
  try {
    db.exec("INSERT INTO HitomiColumnModel VALUES ('2024-02-28'), ('2024-03-01'), (NULL)");
    const days = getDateDistribution(db, '1', 'same');
    assert.equal(days.unit, 'day');
    assert.deepEqual(days.buckets.map((bucket) => bucket.count), [1, 0, 1]);
    assert.equal(days.invalidCount, 1);
    assert.equal(getDateDistribution(other, '1', 'same').totalCount, 0);
    db.exec("INSERT INTO HitomiColumnModel VALUES ('2010-01-01')");
    const years = getDateDistribution(db, '1', 'same');
    assert.equal(years.unit, 'year');
    assert.equal(years.buckets.length, 15);
    assert.equal(years.totalCount, 3);
    db.exec('BEGIN; DELETE FROM HitomiColumnModel');
    assert.equal(getDateDistribution(db, '1', 'same').totalCount, 0);
    db.exec('ROLLBACK');
    assert.equal(getDateDistribution(db, '1', 'same').totalCount, 3);
  } finally { db.close(); other.close(); }
});

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
