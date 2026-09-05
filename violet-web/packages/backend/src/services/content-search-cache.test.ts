import assert from 'node:assert/strict';
import { test } from 'node:test';
import { mkdtempSync, readdirSync, unlinkSync, rmdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import Database from 'better-sqlite3';
import { getCachedSearchCount, getCachedSearchResult } from './content-search-cache.js';

const countSql = 'SELECT COUNT(*) cnt FROM works';
const sql = 'SELECT * FROM works ORDER BY Id DESC LIMIT 30';
const search = (db: Database.Database) => getCachedSearchResult(db, sql, countSql, 0, 30);

test('reuses rows/counts and isolates pages, SQL, connections, and caller mutations', () => {
  const executed: string[] = [];
  const db = new Database(':memory:', { verbose: (value) => executed.push(String(value)) });
  const other = new Database(':memory:');
  try {
    for (const connection of [db, other]) connection.exec('CREATE TABLE works (Id INTEGER PRIMARY KEY, Title TEXT)');
    db.exec("INSERT INTO works VALUES (1,'first'),(2,'second')");
    assert.equal(getCachedSearchCount(db, countSql), 2);
    executed.length = 0;
    const first = search(db);
    assert.equal(first.cacheHit, false);
    assert.equal(executed.includes(countSql), false, 'count is shared with the standalone count API');
    first.result.articles[0].Title = 'mutated';
    executed.length = 0;
    const cached = search(db);
    assert.equal(cached.cacheHit, true);
    assert.equal(cached.result.articles[0].Title, 'second');
    assert.equal(executed.includes(sql), false);
    assert.equal(getCachedSearchResult(db, sql + ' OFFSET 1', countSql, 1, 30).result.articles[0].Id, 1);
    assert.equal(getCachedSearchResult(db, 'SELECT * FROM works WHERE Id=1', 'SELECT 1 cnt', 0, 30).result.totalCount, 1);
    assert.equal(search(other).result.totalCount, 0);
  } finally { db.close(); other.close(); }
});

test('invalidates for external and local writes, and never caches transaction snapshots', () => {
  const dir = mkdtempSync(join(tmpdir(), 'violet-search-cache-'));
  const db = new Database(join(dir, 'data.db'));
  const writer = new Database(join(dir, 'data.db'));
  try {
    db.exec('PRAGMA journal_mode=WAL; CREATE TABLE works (Id INTEGER PRIMARY KEY, Title TEXT)');
    assert.equal(search(db).result.totalCount, 0);
    writer.exec("INSERT INTO works VALUES (1,'external')");
    assert.equal(search(db).result.totalCount, 1);
    db.exec("UPDATE works SET Title='local'");
    assert.equal(search(db).result.articles[0].Title, 'local');
    db.exec('BEGIN; DELETE FROM works');
    assert.equal(search(db).cacheHit, false);
    assert.equal(search(db).result.totalCount, 0);
    db.exec('ROLLBACK');
    assert.equal(search(db).result.totalCount, 1);
    writer.exec("UPDATE works SET Title='revised'");
    assert.equal(search(db).result.articles[0].Title, 'revised');
  } finally {
    writer.close(); db.close();
    for (const file of readdirSync(dir)) unlinkSync(join(dir, file));
    rmdirSync(dir);
  }
});

test('limits result lifetime, entry count, and serialized payload memory', () => {
  const db = new Database(':memory:');
  const realNow = Date.now;
  let now = realNow();
  Date.now = () => now;
  try {
    db.exec("CREATE TABLE works (Id INTEGER PRIMARY KEY, Title TEXT); INSERT INTO works VALUES (1,'first')");
    search(db);
    assert.equal(search(db).cacheHit, true);
    now += 30_001;
    assert.equal(search(db).cacheHit, false);
    for (let i = 0; i < 100; i++) getCachedSearchResult(db, `${sql} -- ${i}`, countSql, 0, 30);
    assert.equal(search(db).cacheHit, false);
    const largeSql = "SELECT 1 Id, replace(hex(zeroblob(1600000)), '0', 'a') Title";
    for (let i = 0; i < 3; i++) getCachedSearchResult(db, `${largeSql} -- ${i}`, countSql, 0, 30);
    assert.equal(getCachedSearchResult(db, `${largeSql} -- 0`, countSql, 0, 30).cacheHit, false);
  } finally { Date.now = realNow; db.close(); }
});
