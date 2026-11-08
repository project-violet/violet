import type Database from 'better-sqlite3';
import type { MessageSearchFilters } from '@violet-web/shared';
import { translateQueryCondition } from './query-engine.js';
import { normalizedPublishedSql, parseDateBounds } from './publication-date.js';

/** Resolve exact work IDs before FSCM scoring/top-k; never truncate the scope. */
export function resolveMessageSearchIds(
  db: Database.Database,
  articleQuery: string,
  filters: MessageSearchFilters = {},
  articleId?: number,
): number[] {
  // The DSL's column fallback is permissive; accept only documented namespaces here.
  const namespaces = new Set(['artist', 'tag', 'male', 'female', 'series', 'group', 'lang', 'type', 'class', 'uploader', 'character']);
  for (const token of articleQuery.split(/[\s()]+/)) {
    if (token.includes(':') && !namespaces.has(token.replace(/^-/, '').split(':')[0])) {
      throw new Error('Invalid article query namespace');
    }
  }
  const dates = parseDateBounds(filters.from, filters.to);
  const conditions = [`(${translateQueryCondition(articleQuery)})`, 'ExistOnHitomi=1'];
  const params: (string | number)[] = [];
  if (dates.from) { conditions.push(`${normalizedPublishedSql()} >= ?`); params.push(dates.from); }
  if (dates.toExclusive) { conditions.push(`${normalizedPublishedSql()} < ?`); params.push(dates.toExclusive); }
  if (filters.idMin !== undefined) { conditions.push('Id >= ?'); params.push(filters.idMin); }
  if (filters.idMax !== undefined) { conditions.push('Id <= ?'); params.push(filters.idMax); }
  if (articleId !== undefined) { conditions.push('Id = ?'); params.push(articleId); }
  const ids = db.prepare(`SELECT Id FROM HitomiColumnModel WHERE ${conditions.join(' AND ')} ORDER BY Id`)
    .pluck().all(...params) as number[];
  return ids;
}
