import assert from 'node:assert/strict';
import { test } from 'node:test';
import Database from 'better-sqlite3';
import { ensureLanguageSearchIndex } from './fts-indexer.js';
import { translateQuery } from './query-engine.js';

test('language index upgrade preserves results, existing tables and indexes, and covers counts', () => {
  const db = new Database(':memory:');
  try {
    db.exec(`CREATE TABLE HitomiColumnModel (Id INTEGER PRIMARY KEY, Language TEXT, ExistOnHitomi INTEGER);
      CREATE INDEX idx_language ON HitomiColumnModel(Language);
      CREATE TABLE FtsPreservationSentinel (value TEXT);
      INSERT INTO FtsPreservationSentinel VALUES ('keep');
      INSERT INTO HitomiColumnModel VALUES (1,'korean',1),(2,'korean',0),(3,'english',1),(4,NULL,1),(5,'korean',1);`);
    const { sql, countSql } = translateQuery('lang:korean', 0, 30);
    const rows = db.prepare(sql).all();
    const count = db.prepare(countSql).get();
    const schema = db.prepare("SELECT name,sql FROM sqlite_master WHERE type='table' ORDER BY name").all();
    ensureLanguageSearchIndex(db);
    ensureLanguageSearchIndex(db);
    assert.deepEqual(db.prepare(sql).all(), rows);
    assert.deepEqual(db.prepare(countSql).get(), count);
    assert.deepEqual(db.prepare("SELECT name,sql FROM sqlite_master WHERE type='table' ORDER BY name").all(), schema);
    assert.deepEqual(db.prepare('SELECT * FROM FtsPreservationSentinel').all(), [{ value: 'keep' }]);
    assert.ok(db.prepare("SELECT 1 FROM sqlite_master WHERE name='idx_language'").get());
    const plan = db.prepare('EXPLAIN QUERY PLAN ' + countSql).all() as Array<{ detail: string }>;
    assert.ok(plan.some((row) => row.detail.includes('COVERING INDEX idx_language_exist_id')));
  } finally { db.close(); }
});
