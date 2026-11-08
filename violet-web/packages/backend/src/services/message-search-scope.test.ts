import assert from 'node:assert/strict';
import { test } from 'node:test';
import Database from 'better-sqlite3';
import { resolveMessageSearchIds } from './message-search-scope.js';

function fixture() {
  const db = new Database(':memory:');
  db.exec(`CREATE TABLE HitomiColumnModel (Id INTEGER PRIMARY KEY, Title TEXT, ExistOnHitomi INTEGER, Language TEXT, Tags TEXT, Artists TEXT, Files INTEGER, Published TEXT);
    INSERT INTO HitomiColumnModel VALUES
    (10, 'first', 1, 'korean', '|tag one|', '|author|', 120, '2025-01-10 00:00:00'),
    (20, 'second', 1, 'english', '|tag one|', '|author|', 150, '2025-01-15 00:00:00'),
    (30, 'third', 1, 'korean', '|tag one|', '|author|', 200, '2025-02-10 00:00:00'),
    (40, 'fourth', 1, 'korean', '|tag two|', '|other|', 50, '2025-01-20 00:00:00'),
    (50, 'removed', 0, 'korean', '|tag one|', '|author|', 120, '2025-01-12 00:00:00');`);
  return db;
}

test('resolves exact tags, exclusions, pages, dates and ID intersections', () => {
  const db = fixture();
  try {
    assert.deepEqual(resolveMessageSearchIds(db, 'lang:korean tag:tag_one page>100'), [10, 30]);
    assert.deepEqual(resolveMessageSearchIds(db, 'artist:author -lang:english', { from: '2025-01-01', to: '2025-01-31' }), [10]);
    assert.deepEqual(resolveMessageSearchIds(db, 'lang:korean', { idMin: 20, idMax: 40 }), [30, 40]);
    assert.deepEqual(resolveMessageSearchIds(db, 'lang:korean', {}, 20), []);
    assert.deepEqual(resolveMessageSearchIds(db, 'lang:missing'), []);
    assert.throws(() => resolveMessageSearchIds(db, 'invalid:column'));
    assert.throws(() => resolveMessageSearchIds(db, 'page>'));
  } finally { db.close(); }
});

test('returns every matching ID beyond 50000 works without truncation', () => {
  const db = fixture();
  try {
    db.exec(`DELETE FROM HitomiColumnModel;
      WITH RECURSIVE ids(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM ids WHERE n<50000)
      INSERT INTO HitomiColumnModel (Id, ExistOnHitomi, Language) SELECT n, 1, 'korean' FROM ids;`);
    assert.equal(resolveMessageSearchIds(db, 'lang:korean').length, 50_000);
    db.exec("INSERT INTO HitomiColumnModel (Id, ExistOnHitomi, Language) VALUES (50001, 1, 'korean')");
    const ids = resolveMessageSearchIds(db, 'lang:korean');
    assert.equal(ids.length, 50_001);
    assert.equal(ids.at(-1), 50_001);
  } finally { db.close(); }
});
