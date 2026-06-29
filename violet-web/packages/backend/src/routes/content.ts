import { Router } from 'express';
import { getContentDb, isContentDbReady, isFtsReady } from '../services/content-db.js';
import { translateQuery, translateQueryCondition } from '../services/query-engine.js';
import {
  buildSuggestionCache,
  loadSuggestionCacheFromFile,
  searchSuggestions,
  getCacheStatus,
  getTagCounts,
} from '../services/suggestion-engine.js';
import type { SuggestionCategory, TagEntry } from '@violet-web/shared';

// Load cache from file on startup, or build from DB if file not available
if (!loadSuggestionCacheFromFile() && isContentDbReady()) {
  console.log('No suggestion cache file found, building from DB...');
  buildSuggestionCache(getContentDb());
}

export const contentRouter = Router();

// COUNT cache: same query string → cached count (expires after 60s)
const countCache = new Map<string, { count: number; ts: number }>();
const COUNT_CACHE_TTL = 60_000;
const tagSummaryCache = new Map<string, { tags: TagEntry[]; ts: number }>();
const TAG_SUMMARY_CACHE_TTL = 60_000;
const contextualSuggestionCache = new Map<string, { suggestions: TagEntry[]; ts: number }>();
const CONTEXTUAL_SUGGESTION_CACHE_TTL = 60_000;

function getCachedCount(query: string): number | null {
  const entry = countCache.get(query);
  if (entry && Date.now() - entry.ts < COUNT_CACHE_TTL) return entry.count;
  return null;
}

function getSearchCount(query: string, useFts: boolean): number {
  const cached = getCachedCount(query);
  if (cached !== null) return cached;

  const db = getContentDb();
  try {
    const { countSql } = translateQuery(query, 0, 1, useFts);
    const countRow = db.prepare(countSql).get() as { cnt: number } | undefined;
    const count = countRow?.cnt ?? 0;
    countCache.set(query, { count, ts: Date.now() });
    return count;
  } catch {
    try {
      const { countSql } = translateQuery(query, 0, 1, false);
      const countRow = db.prepare(countSql).get() as { cnt: number } | undefined;
      const count = countRow?.cnt ?? 0;
      countCache.set(query, { count, ts: Date.now() });
      return count;
    } catch {
      return 0;
    }
  }
}

function parsePipeTags(value: string | null): string[] {
  if (!value) return [];
  return value
    .split('|')
    .map((tag) => tag.trim())
    .filter(Boolean);
}

function incrementTag(
  map: Map<string, { category: SuggestionCategory; tag: string; count: number }>,
  category: SuggestionCategory,
  tag: string,
) {
  const key = `${category}:${tag}`;
  const entry = map.get(key);
  if (entry) {
    entry.count += 1;
  } else {
    map.set(key, { category, tag, count: 1 });
  }
}

function toQueryToken(tag: string): string {
  return tag.replace(/\s+/g, '_');
}

function buildTagSummary(rows: Array<{
  Artists: string | null;
  Series: string | null;
  Characters: string | null;
  Groups: string | null;
  Tags: string | null;
}>, limit: number): TagEntry[] {
  const tagMap = new Map<string, { category: SuggestionCategory; tag: string; count: number }>();

  for (const row of rows) {
    parsePipeTags(row.Artists).forEach((tag) => incrementTag(tagMap, 'artist', tag));
    parsePipeTags(row.Series).forEach((tag) => incrementTag(tagMap, 'series', tag));
    parsePipeTags(row.Characters).forEach((tag) => incrementTag(tagMap, 'character', tag));
    parsePipeTags(row.Groups).forEach((tag) => incrementTag(tagMap, 'group', tag));
    parsePipeTags(row.Tags).forEach((rawTag) => {
      const colonIdx = rawTag.indexOf(':');
      if (colonIdx >= 0) {
        const namespace = rawTag.substring(0, colonIdx);
        const tag = rawTag.substring(colonIdx + 1);
        const category: SuggestionCategory =
          namespace === 'male' ? 'male' : namespace === 'female' ? 'female' : 'tag';
        incrementTag(tagMap, category, tag);
      } else {
        incrementTag(tagMap, 'tag', rawTag);
      }
    });
  }

  return Array.from(tagMap.values())
    .sort((a, b) => b.count - a.count)
    .slice(0, limit)
    .map((entry) => ({
      ...entry,
      display: `${entry.category}:${toQueryToken(entry.tag)}`,
    }));
}

contentRouter.get('/search', (req, res) => {
  if (!isContentDbReady()) {
    res.status(503).json({ error: 'Database syncing, please wait.' });
    return;
  }

  const query = (req.query.q as string) || '';
  const page = parseInt(req.query.page as string) || 0;
  const pageSize = Math.min(parseInt(req.query.pageSize as string) || 30, 100);

  const db = getContentDb();
  const useFts = isFtsReady();
  let { sql, countSql } = translateQuery(query, page, pageSize, useFts);

  try {
    const t0 = performance.now();
    const articles = db.prepare(sql).all();
    const tQuery = performance.now() - t0;

    const cached = getCachedCount(query);
    let totalCount: number;
    let tCount: number;
    if (cached !== null) {
      totalCount = cached;
      tCount = 0;
    } else {
      const countRow = db.prepare(countSql).get() as { cnt: number } | undefined;
      tCount = performance.now() - t0 - tQuery;
      totalCount = countRow?.cnt ?? 0;
      countCache.set(query, { count: totalCount, ts: Date.now() });
    }

    console.log(`[SQL] query=${tQuery.toFixed(1)}ms count=${tCount.toFixed(1)}ms${cached !== null ? '(cached)' : ''} total=${(tQuery+tCount).toFixed(1)}ms | q="${query}" fts=${useFts} | ${totalCount} results`);
    res.json({ articles, totalCount, page, pageSize });
  } catch {
    // FTS query failed, fall back to LIKE
    const fallback = translateQuery(query, page, pageSize, false);
    const t0 = performance.now();
    const articles = db.prepare(fallback.sql).all();
    const tQuery = performance.now() - t0;
    const countRow = db.prepare(fallback.countSql).get() as { cnt: number } | undefined;
    const tCount = performance.now() - t0 - tQuery;
    const totalCount = countRow?.cnt ?? 0;
    countCache.set(query, { count: totalCount, ts: Date.now() });
    console.log(`[SQL] query=${tQuery.toFixed(1)}ms count=${tCount.toFixed(1)}ms total=${(tQuery+tCount).toFixed(1)}ms | q="${query}" fts=fallback | ${totalCount} results`);
    res.json({ articles, totalCount, page, pageSize });
  }
});

contentRouter.get('/search/tags', (req, res) => {
  if (!isContentDbReady()) {
    res.status(503).json({ error: 'Database syncing, please wait.' });
    return;
  }

  const query = (req.query.q as string) || '';
  const limit = Math.min(parseInt(req.query.limit as string) || 30, 100);
  const cacheKey = `${query}\0${limit}`;
  const cached = tagSummaryCache.get(cacheKey);
  if (cached && Date.now() - cached.ts < TAG_SUMMARY_CACHE_TTL) {
    res.json({ tags: cached.tags });
    return;
  }

  const db = getContentDb();
  const useFts = isFtsReady();

  try {
    const condition = translateQueryCondition(query, useFts);
    const rows = db
      .prepare(`SELECT Artists, Series, Characters, Groups, Tags FROM HitomiColumnModel WHERE ${condition}`)
      .all() as Array<{
        Artists: string | null;
        Series: string | null;
        Characters: string | null;
        Groups: string | null;
        Tags: string | null;
      }>;
    const tags = buildTagSummary(rows, limit);
    tagSummaryCache.set(cacheKey, { tags, ts: Date.now() });
    res.json({ tags });
  } catch {
    const condition = translateQueryCondition(query, false);
    const rows = db
      .prepare(`SELECT Artists, Series, Characters, Groups, Tags FROM HitomiColumnModel WHERE ${condition}`)
      .all() as Array<{
        Artists: string | null;
        Series: string | null;
        Characters: string | null;
        Groups: string | null;
        Tags: string | null;
      }>;
    const tags = buildTagSummary(rows, limit);
    tagSummaryCache.set(cacheKey, { tags, ts: Date.now() });
    res.json({ tags });
  }
});

// Suggestion endpoints (must be before /:id route)
contentRouter.get('/suggest/contextual', (req, res) => {
  if (!isContentDbReady()) {
    res.status(503).json({ error: 'Database syncing, please wait.' });
    return;
  }

  const q = (req.query.q as string) || '';
  const base = ((req.query.base as string) || '').trim();
  const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);

  if (!q.trim()) {
    res.json({ suggestions: [] });
    return;
  }

  if (!base) {
    res.json({ suggestions: searchSuggestions(q, limit) });
    return;
  }

  const cacheKey = `${base}\0${q}\0${limit}`;
  const cached = contextualSuggestionCache.get(cacheKey);
  if (cached && Date.now() - cached.ts < CONTEXTUAL_SUGGESTION_CACHE_TTL) {
    res.json({ suggestions: cached.suggestions });
    return;
  }

  const useFts = isFtsReady();
  const candidates = searchSuggestions(q, Math.min(limit * 5, 100));
  const suggestions: TagEntry[] = [];

  for (const candidate of candidates) {
    const countQuery = `${base} ${candidate.display}`.trim();
    const contextualCount = getSearchCount(countQuery, useFts);
    if (contextualCount > 0) {
      suggestions.push({ ...candidate, contextualCount });
    }
  }

  suggestions.sort((a, b) => (b.contextualCount ?? 0) - (a.contextualCount ?? 0));
  const limited = suggestions.slice(0, limit);
  contextualSuggestionCache.set(cacheKey, { suggestions: limited, ts: Date.now() });
  res.json({ suggestions: limited });
});

contentRouter.get('/suggest', (req, res) => {
  if (!isContentDbReady()) {
    res.status(503).json({ error: 'Database syncing, please wait.' });
    return;
  }

  const q = (req.query.q as string) || '';
  const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);

  const suggestions = searchSuggestions(q, limit);
  res.json({ suggestions });
});

contentRouter.post('/suggest/rebuild', (req, res) => {
  if (!isContentDbReady()) {
    res.status(503).json({ error: 'Database syncing, please wait.' });
    return;
  }

  try {
    const db = getContentDb();
    buildSuggestionCache(db);
    res.json({ success: true });
  } catch (error) {
    console.error('Failed to build suggestion cache:', error);
    res.status(500).json({ error: 'Failed to build cache' });
  }
});

contentRouter.get('/suggest/tag-counts', (_req, res) => {
  res.json(getTagCounts());
});

contentRouter.get('/suggest/status', (req, res) => {
  const status = getCacheStatus();
  res.json(status);
});

contentRouter.post('/batch', (req, res) => {
  if (!isContentDbReady()) {
    res.status(503).json({ error: 'Database syncing, please wait.' });
    return;
  }

  const ids: number[] = req.body.ids;
  if (!Array.isArray(ids) || ids.length === 0) {
    res.json({ articles: [] });
    return;
  }

  // Limit to 5000 per request
  const limited = ids.slice(0, 5000);
  const db = getContentDb();
  const placeholders = limited.map(() => '?').join(',');
  const articles = db
    .prepare(`SELECT * FROM HitomiColumnModel WHERE Id IN (${placeholders})`)
    .all(...limited);

  // Preserve original order
  const articleMap = new Map(articles.map((a: any) => [a.Id, a]));
  const ordered = limited.map((id) => articleMap.get(id)).filter(Boolean);

  res.json({ articles: ordered });
});

contentRouter.get('/:id', (req, res) => {
  if (!isContentDbReady()) {
    res.status(503).json({ error: 'Database syncing, please wait.' });
    return;
  }

  const id = parseInt(req.params.id);
  if (isNaN(id)) {
    res.status(400).json({ error: 'Invalid id' });
    return;
  }

  const db = getContentDb();
  const article = db
    .prepare('SELECT * FROM HitomiColumnModel WHERE Id = ?')
    .get(id);

  if (!article) {
    res.status(404).json({ error: 'Not found' });
    return;
  }

  res.json(article);
});
