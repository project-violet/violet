import type Database from 'better-sqlite3';
import type { Article, ArticleSearchResult } from '@violet-web/shared';
import { BoundedCache } from './bounded-cache.js';

const RESULT_TTL = 30_000;
const MAX_RESULT_BYTES = 8 * 1024 * 1024;
const MAX_RESULT_ENTRIES = 100;
type ResultEntry = { json: string; bytes: number; ts: number };
type SearchCache = {
  revision: string;
  counts: BoundedCache<{ count: number; ts: number }>;
  results: Map<string, ResultEntry>;
  bytes: number;
};
const caches = new WeakMap<Database.Database, SearchCache>();

function getCache(db: Database.Database): SearchCache | undefined {
  // Do not reuse committed results inside another transaction's snapshot.
  if (db.inTransaction) return undefined;
  const revision = `${db.pragma('data_version', { simple: true })}:${db.pragma('schema_version', { simple: true })}:${db.prepare('SELECT total_changes()').pluck().get()}`;
  let cache = caches.get(db);
  if (!cache || cache.revision !== revision) {
    cache = { revision, counts: new BoundedCache(), results: new Map(), bytes: 0 };
    caches.set(db, cache);
  }
  return cache;
}

function countRows(db: Database.Database, sql: string, cache?: SearchCache): number {
  const entry = cache?.counts.get(sql);
  if (entry && Date.now() - entry.ts < 60_000) return entry.count;
  const count = (db.prepare(sql).get() as { cnt: number } | undefined)?.cnt ?? 0;
  cache?.counts.set(sql, { count, ts: Date.now() });
  return count;
}

/** SQL keys keep FTS/fallback/date semantics distinct and share counts across pages. */
export function getCachedSearchCount(db: Database.Database, countSql: string): number {
  return countRows(db, countSql, getCache(db));
}

export function getCachedSearchResult(
  db: Database.Database,
  sql: string,
  countSql: string,
  page: number,
  pageSize: number,
): { result: ArticleSearchResult; cacheHit: boolean } {
  const cache = getCache(db);
  const key = JSON.stringify([sql, countSql, page, pageSize]);
  const now = Date.now();
  if (cache) {
    for (const [entryKey, entry] of cache.results) {
      if (now - entry.ts >= RESULT_TTL) {
        cache.results.delete(entryKey);
        cache.bytes -= entry.bytes;
      }
    }
    const entry = cache.results.get(key);
    if (entry) return { result: JSON.parse(entry.json) as ArticleSearchResult, cacheHit: true };
  }
  const articles = db.prepare(sql).all() as Article[];
  const totalCount = countRows(db, countSql, cache);
  const result = { articles, totalCount, page, pageSize };
  if (cache) {
    const json = JSON.stringify(result);
    const bytes = Buffer.byteLength(json) + Buffer.byteLength(key);
    if (bytes <= MAX_RESULT_BYTES) {
      while (cache.results.size >= MAX_RESULT_ENTRIES || cache.bytes + bytes > MAX_RESULT_BYTES) {
        const oldestKey = cache.results.keys().next().value!;
        cache.bytes -= cache.results.get(oldestKey)!.bytes;
        cache.results.delete(oldestKey);
      }
      cache.results.set(key, { json, bytes, ts: now });
      cache.bytes += bytes;
    }
  }
  return { result, cacheHit: false };
}
