import assert from 'node:assert/strict';
import { test } from 'node:test';
import Database from 'better-sqlite3';
import { mkdtempSync, unlinkSync, rmdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { parseArticleIdBound, resolveMessageSearchRange } from './message-search-range.js';

test('ID bounds reject malformed, reversed and out-of-u32 ranges', () => {
  for (const value of ['-1', '2.5', '123abc', '4294967296', ['1']]) {
    assert.throws(() => parseArticleIdBound(value));
  }
  assert.equal(parseArticleIdBound('4294967295'), 4294967295);
  assert.deepEqual(resolveMessageSearchRange(undefined, undefined, undefined, { idMin: 20 }), { idMin: 20 });
  assert.throws(() => resolveMessageSearchRange(undefined, undefined, undefined, { idMin: 20, idMax: 10 }));
});

test('dates produce inclusive ID bounds, intersect manual bounds, and never fall back on empty dates', () => {
  const db = new Database(':memory:');
  db.exec(`CREATE TABLE HitomiColumnModel (Id INTEGER, Published, ExistOnHitomi INTEGER);
    INSERT INTO HitomiColumnModel VALUES
    (10, '2025-01-01 00:00:00', 1), (20, '2025-01-01 23:59:59', 1),
    (30, '2025-01-02 00:00:00', 1), (99, '2025-01-01', 0);`);
  assert.deepEqual(resolveMessageSearchRange(db, '2025-01-01', '2025-01-01', {}), { idMin: 10, idMax: 20 });
  assert.deepEqual(resolveMessageSearchRange(db, '2025-01-01', undefined, { idMin: 15, idMax: 25 }), { idMin: 15, idMax: 25 });
  assert.deepEqual(resolveMessageSearchRange(db, undefined, '2025-01-01', {}), { idMin: 10, idMax: 20 });
  assert.equal(resolveMessageSearchRange(db, '2030-01-01', undefined, {}), null);
  assert.equal(resolveMessageSearchRange(db, '2025-01-01', '2025-01-01', { idMin: 21 }), null);
  assert.throws(() => resolveMessageSearchRange(db, '2025-02-30', undefined, {}));
  db.close();
});

test('cached date bounds follow writes from both connections and exclude rolled-back transaction results', () => {
  const directory = mkdtempSync(join(tmpdir(), 'violet-range-cache-'));
  const filename = join(directory, 'data.db');
  const db = new Database(filename);
  const writer = new Database(filename);
  try {
    db.exec('CREATE TABLE HitomiColumnModel (Id INTEGER, Published TEXT, ExistOnHitomi INTEGER)');
    const read = (idMin?: number) => resolveMessageSearchRange(db, '2026-01-01', '2026-01-01', { idMin });
    assert.equal(read(), null);
    writer.exec("INSERT INTO HitomiColumnModel VALUES (10, '2026-01-01', 1)");
    assert.deepEqual(read(), { idMin: 10, idMax: 10 });
    db.exec("INSERT INTO HitomiColumnModel VALUES (20, '2026-01-01', 1)");
    assert.deepEqual(read(15), { idMin: 15, idMax: 20 });
    assert.deepEqual(read(), { idMin: 10, idMax: 20 });
    db.exec("BEGIN; INSERT INTO HitomiColumnModel VALUES (30, '2026-01-01', 1)");
    assert.deepEqual(read(), { idMin: 10, idMax: 30 });
    db.exec('ROLLBACK');
    assert.deepEqual(read(), { idMin: 10, idMax: 20 });
    writer.exec('DELETE FROM HitomiColumnModel');
    assert.equal(read(), null);
  } finally {
    writer.close(); db.close();
    unlinkSync(filename); rmdirSync(directory);
  }
});
