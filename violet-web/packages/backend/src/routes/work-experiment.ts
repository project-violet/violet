import { Router } from 'express';
import { performance } from 'node:perf_hooks';
import type { MessageSearchMode, MessageSearchResponse, MessageSearchResult } from '@violet-web/shared';
import { getContentDb, isContentDbReady } from '../services/content-db.js';

export const workExperimentRouter = Router();

const DEFAULT_FSCM_BASE_URL = 'http://127.0.0.1:12332';
const DEFAULT_TIMEOUT_MS = 30_000;
const AUTHOR_WORK_LIMIT = 5_000;
const authorArticleIdsCache = new Map<string, string[]>();
const graphWorkSetCache = new Map<string, GraphWorkResponse>();
const graphWorkSetInflight = new Map<string, Promise<GraphWorkResponse>>();

function elapsedMs(start: number, end = performance.now()): string {
  return (end - start).toFixed(3);
}

function profileValue(value: unknown): string {
  if (typeof value === 'string') return JSON.stringify(value);
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  if (value === null) return 'null';
  if (value === undefined) return 'undefined';
  return JSON.stringify(value);
}

function logWorkExperimentProfile(event: string, fields: Record<string, unknown>): void {
  const body = Object.entries(fields)
    .map(([key, value]) => `${key}=${profileValue(value)}`)
    .join(' ');
  console.log(`[work-experiment-profile] event=${event} ${body}`);
}

interface FscmRawResult {
  Id?: unknown;
  Page?: unknown;
  Correctness?: unknown;
  MatchScore?: unknown;
  Rect?: unknown;
}

interface GraphWorkResponse {
  article_id: string;
  article_ids?: string[];
  work_count?: number;
  score: number;
  matched_count: number;
  matched_keywords: unknown[];
  top_keywords: unknown[];
  total_pages: number;
  dialogue_count: number;
  char_count: number;
}

type CacheStatus = 'hit' | 'miss' | 'inflight';

interface CachedGraphWorkSetResult {
  work: GraphWorkResponse;
  cacheStatus: CacheStatus;
}

function normalizeBaseUrl(raw: unknown, fallback: string): string | null {
  const value = typeof raw === 'string' && raw.trim() ? raw.trim() : fallback;

  try {
    const url = new URL(value);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return null;
    return url.origin;
  } catch {
    return null;
  }
}

function getTimeoutMs(): number {
  const parsed = Number(process.env.FSCM_TIMEOUT_MS);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : DEFAULT_TIMEOUT_MS;
}

function escapeLike(value: string): string {
  return value.replace(/[\\%_]/g, (match) => `\\${match}`);
}

function normalizeAuthor(value: unknown): string {
  return typeof value === 'string' ? value.trim().replace(/_/g, ' ') : '';
}

function normalizeLimit(value: unknown): number {
  return Math.max(1, Math.min(500, parseInt(String(value)) || 100));
}

function toFiniteNumber(value: unknown): number | null {
  const num = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(num) ? num : null;
}

function normalizeResult(raw: FscmRawResult): MessageSearchResult | null {
  const articleId = toFiniteNumber(raw.Id);
  const page = toFiniteNumber(raw.Page);
  const correctness = toFiniteNumber(raw.Correctness);

  if (articleId === null || page === null || correctness === null) return null;
  if (!Array.isArray(raw.Rect) || raw.Rect.length !== 4) return null;

  const rect = raw.Rect.map(toFiniteNumber);
  if (rect.some((value) => value === null)) return null;

  const matchScore =
    typeof raw.MatchScore === 'number' || typeof raw.MatchScore === 'string'
      ? raw.MatchScore
      : '';

  return {
    articleId,
    page,
    rect: rect as [number, number, number, number],
    matchScore,
    correctness,
  };
}

function resultScore(result: MessageSearchResult): number {
  const score = typeof result.matchScore === 'number' ? result.matchScore : Number(result.matchScore);
  return Number.isFinite(score) ? score : Number.NEGATIVE_INFINITY;
}

function sortMessageResults(results: MessageSearchResult[]): MessageSearchResult[] {
  return results.sort((a, b) => {
    const scoreDiff = resultScore(b) - resultScore(a);
    if (scoreDiff !== 0) return scoreDiff;
    if (a.correctness !== b.correctness) return b.correctness - a.correctness;
    if (a.articleId !== b.articleId) return b.articleId - a.articleId;
    return a.page - b.page;
  });
}

export function buildFscmWorkMessageRequest(
  baseUrl: string,
  query: string,
  articleIds: string[],
  mode: MessageSearchMode,
  limit: number,
): { url: string; body: string; ids: number[] } {
  const route = mode === 'similar' ? 'wsimilar' : 'wcontains';
  const ids = articleIds
    .map((articleId) => Number(articleId))
    .filter((articleId) => Number.isInteger(articleId) && articleId > 0);

  return {
    url: `${baseUrl}/${route}`,
    body: JSON.stringify({ ids, query, limit }),
    ids,
  };
}

async function fetchFscmWorkMessages(
  baseUrl: string,
  query: string,
  articleIds: string[],
  mode: MessageSearchMode,
  limit: number,
): Promise<MessageSearchResult[]> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), getTimeoutMs());
  const upstreamRequest = buildFscmWorkMessageRequest(baseUrl, query, articleIds, mode, limit);
  const totalStart = performance.now();
  const fetchStart = performance.now();

  try {
    const response = await fetch(upstreamRequest.url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: upstreamRequest.body,
      signal: controller.signal,
    });
    const fetchEnd = performance.now();
    if (!response.ok) {
      throw new Error(`fscm returned ${response.status}`);
    }
    const jsonStart = performance.now();
    const raw = await response.json();
    const jsonEnd = performance.now();
    if (!Array.isArray(raw)) {
      throw new Error('fscm returned an invalid response');
    }
    const normalizeStart = performance.now();
    const results = raw
      .map((item) => normalizeResult(item as FscmRawResult))
      .filter((item): item is MessageSearchResult => item !== null);
    const normalizeEnd = performance.now();

    logWorkExperimentProfile('fscm', {
      route: mode === 'similar' ? 'wsimilar' : 'wcontains',
      ids: upstreamRequest.ids.length,
      query,
      limit,
      status: response.status,
      raw: raw.length,
      normalized: results.length,
      fetch_ms: elapsedMs(fetchStart, fetchEnd),
      json_ms: elapsedMs(jsonStart, jsonEnd),
      normalize_ms: elapsedMs(normalizeStart, normalizeEnd),
      total_ms: elapsedMs(totalStart, normalizeEnd),
    });

    return results;
  } finally {
    clearTimeout(timeout);
  }
}

async function fetchGraphWorkSet(
  baseUrl: string,
  articleIds: string[],
): Promise<GraphWorkResponse> {
  const totalStart = performance.now();
  const fetchStart = performance.now();
  const response = await fetch(`${baseUrl}/api/works`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ ids: articleIds }),
  });
  const fetchEnd = performance.now();
  const jsonStart = performance.now();
  const payload = await response.json().catch(() => null);
  const jsonEnd = performance.now();
  if (!response.ok) {
    const message = typeof (payload as { error?: unknown } | null)?.error === 'string'
      ? (payload as { error: string }).error
      : `violet-graph returned ${response.status}`;
    throw new Error(message);
  }
  logWorkExperimentProfile('graph', {
    ids: articleIds.length,
    status: response.status,
    work_count: (payload as GraphWorkResponse | null)?.work_count,
    matched_count: (payload as GraphWorkResponse | null)?.matched_count,
    fetch_ms: elapsedMs(fetchStart, fetchEnd),
    json_ms: elapsedMs(jsonStart, jsonEnd),
    total_ms: elapsedMs(totalStart, jsonEnd),
  });
  return payload as GraphWorkResponse;
}

function graphWorkSetCacheKey(baseUrl: string, articleIds: string[]): string {
  return `${baseUrl}\0${articleIds.join('\0')}`;
}

async function getCachedGraphWorkSet(
  baseUrl: string,
  articleIds: string[],
): Promise<CachedGraphWorkSetResult> {
  const cacheKey = graphWorkSetCacheKey(baseUrl, articleIds);
  const cached = graphWorkSetCache.get(cacheKey);
  if (cached) {
    return { work: cached, cacheStatus: 'hit' };
  }

  const inflight = graphWorkSetInflight.get(cacheKey);
  if (inflight) {
    return { work: await inflight, cacheStatus: 'inflight' };
  }

  const promise = fetchGraphWorkSet(baseUrl, articleIds);
  graphWorkSetInflight.set(cacheKey, promise);
  try {
    const work = await promise;
    graphWorkSetCache.set(cacheKey, work);
    return { work, cacheStatus: 'miss' };
  } finally {
    graphWorkSetInflight.delete(cacheKey);
  }
}

interface AuthorArticleIdsResult {
  articleIds: string[];
  cacheHit: boolean;
}

function findAuthorArticleIds(author: string): AuthorArticleIdsResult {
  const cached = authorArticleIdsCache.get(author);
  if (cached) {
    return { articleIds: cached, cacheHit: true };
  }

  const db = getContentDb();
  const rows = db
    .prepare(
      `SELECT Id FROM HitomiColumnModel
       WHERE ExistOnHitomi = 1 AND Artists LIKE ? ESCAPE '\\'
       ORDER BY Id DESC
       LIMIT ?`,
    )
    .all(`%|${escapeLike(author)}|%`, AUTHOR_WORK_LIMIT) as Array<{ Id: number }>;

  const articleIds = rows.map((row) => String(row.Id));
  authorArticleIdsCache.set(author, articleIds);
  return { articleIds, cacheHit: false };
}

async function searchAuthorMessages(
  baseUrl: string,
  query: string,
  articleIds: string[],
  mode: MessageSearchMode,
  limit: number,
): Promise<MessageSearchResponse | null> {
  const trimmedQuery = query.trim();
  if (!trimmedQuery) return null;
  if (mode !== 'contains' && mode !== 'similar') {
    throw new Error('Author-scoped message search supports contains or similar mode.');
  }

  const results = await fetchFscmWorkMessages(baseUrl, trimmedQuery, articleIds, mode, limit);

  const sortStart = performance.now();
  sortMessageResults(results);
  const sortEnd = performance.now();
  const takeStart = performance.now();
  const sliced = results.slice(0, limit);
  const takeEnd = performance.now();

  logWorkExperimentProfile('messages', {
    mode,
    ids: articleIds.length,
    query: trimmedQuery,
    total: results.length,
    limit,
    returned: sliced.length,
    sort_ms: elapsedMs(sortStart, sortEnd),
    take_ms: elapsedMs(takeStart, takeEnd),
  });

  return {
    query: trimmedQuery,
    mode,
    total: results.length,
    results: sliced,
  };
}

workExperimentRouter.get('/author', async (req, res) => {
  if (!isContentDbReady()) {
    res.status(503).json({ error: 'Database syncing, please wait.' });
    return;
  }

  const author = normalizeAuthor(req.query.author);
  const messageQuery = typeof req.query.q === 'string' ? req.query.q.trim() : '';
  const limit = normalizeLimit(req.query.limit);
  const graphBaseUrl = normalizeBaseUrl(req.query.keywordGraphServerUrl, 'http://127.0.0.1:8787');
  const messageBaseUrl = normalizeBaseUrl(
    req.query.messageSearchServerUrl,
    process.env.FSCM_BASE_URL || DEFAULT_FSCM_BASE_URL,
  );

  if (!author) {
    res.status(400).json({ error: 'Query parameter "author" is required.' });
    return;
  }
  if (!graphBaseUrl) {
    res.status(400).json({ error: 'Invalid violet-graph server URL.' });
    return;
  }
  if (!messageBaseUrl) {
    res.status(400).json({ error: 'Invalid fscm baseUrl.' });
    return;
  }

  const routeStart = performance.now();
  try {
    const idsStart = performance.now();
    const { articleIds, cacheHit: authorIdsCacheHit } = findAuthorArticleIds(author);
    const idsEnd = performance.now();
    if (articleIds.length === 0) {
      res.status(404).json({ error: 'Author works not found.' });
      return;
    }

    const graphStart = performance.now();
    const { work, cacheStatus: graphCacheStatus } = await getCachedGraphWorkSet(graphBaseUrl, articleIds);
    const graphEnd = performance.now();
    const messageStart = performance.now();
    const messages = await searchAuthorMessages(messageBaseUrl, messageQuery, articleIds, 'contains', limit);
    const messageEnd = performance.now();

    logWorkExperimentProfile('author-route', {
      author,
      query: messageQuery,
      ids: articleIds.length,
      id_lookup_cache: authorIdsCacheHit ? 'hit' : 'miss',
      id_lookup_ms: elapsedMs(idsStart, idsEnd),
      graph_cache: graphCacheStatus,
      graph_ms: elapsedMs(graphStart, graphEnd),
      message_ms: elapsedMs(messageStart, messageEnd),
      total_ms: elapsedMs(routeStart),
    });

    res.json({
      scope: 'author',
      author,
      articleIds,
      work,
      messages,
    });
  } catch (error) {
    console.error('Work experiment author error:', error);
    res.status(502).json({ error: error instanceof Error ? error.message : 'Failed to load author experiment.' });
  }
});
