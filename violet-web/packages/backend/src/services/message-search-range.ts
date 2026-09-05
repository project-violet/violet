import type Database from 'better-sqlite3';
import { normalizedPublishedSql, parseDateBounds } from './publication-date.js';

export interface ArticleIdRange { idMin?: number; idMax?: number }

type DateEnvelope = { idMin: number | null; idMax: number | null };
const dateEnvelopeCaches = new WeakMap<Database.Database, {
  revision: string;
  entries: Map<string, DateEnvelope>;
}>();

function getDateEnvelopeCache(db: Database.Database): Map<string, DateEnvelope> | undefined {
  // A transaction can see an older snapshot or uncommitted writes. Do not share it.
  if (db.inTransaction) return undefined;
  // data_version observes other connections (including hsync); total_changes observes
  // writes on this connection. schema_version covers same-connection DDL as well.
  const revision = `${db.pragma('data_version', { simple: true })}:${db.pragma('schema_version', { simple: true })}:${db.prepare('SELECT total_changes()').pluck().get()}`;
  let cache = dateEnvelopeCaches.get(db);
  if (!cache || cache.revision !== revision) {
    cache = { revision, entries: new Map() };
    dateEnvelopeCaches.set(db, cache);
  }
  return cache.entries;
}

export function parseArticleIdBound(value: unknown): number | undefined {
  if (value === undefined || value === '') return undefined;
  if (typeof value !== 'string' || !/^\d+$/.test(value)) throw new Error('Invalid article ID bound');
  const id = Number(value);
  if (!Number.isSafeInteger(id) || id < 0 || id > 0xffffffff) throw new Error('Invalid article ID bound');
  return id;
}

// Publication dates are converted to an inclusive ID envelope, not a per-result date filter.
export function resolveMessageSearchRange(
  db: Database.Database | undefined,
  from: string | undefined,
  to: string | undefined,
  range: ArticleIdRange,
): ArticleIdRange | null {
  const dates = parseDateBounds(from, to);
  if ((range.idMin ?? 0) > (range.idMax ?? 0xffffffff)) throw new Error('Reversed article ID range');
  if (!from && !to) return range;
  if (!db) throw new Error('Content database is required for date filtering');
  const conditions = ['ExistOnHitomi = 1'];
  const params: string[] = [];
  const published = normalizedPublishedSql();
  if (dates.from) { conditions.push(`${published} >= ?`); params.push(dates.from); }
  if (dates.toExclusive) { conditions.push(`${published} < ?`); params.push(dates.toExclusive); }
  const cache = getDateEnvelopeCache(db);
  const cacheKey = JSON.stringify([dates.from, dates.toExclusive]);
  let row = cache?.get(cacheKey);
  if (!row) {
    row = db.prepare(`SELECT MIN(Id) AS idMin, MAX(Id) AS idMax FROM HitomiColumnModel WHERE ${conditions.join(' AND ')}`)
      .get(...params) as DateEnvelope;
    if (cache) {
      if (cache.size >= 100) cache.delete(cache.keys().next().value!);
      cache.set(cacheKey, row);
    }
  }
  if (row.idMin === null || row.idMax === null) return null;
  const idMin = Math.max(range.idMin ?? 0, row.idMin);
  const idMax = Math.min(range.idMax ?? 0xffffffff, row.idMax);
  return idMin <= idMax ? { idMin, idMax } : null;
}
