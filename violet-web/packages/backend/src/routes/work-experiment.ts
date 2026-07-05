import { Router } from 'express';
import type { MessageSearchMode, MessageSearchResponse, MessageSearchResult } from '@violet-web/shared';
import { getContentDb, isContentDbReady } from '../services/content-db.js';

export const workExperimentRouter = Router();

const DEFAULT_FSCM_BASE_URL = 'http://127.0.0.1:12332';
const DEFAULT_TIMEOUT_MS = 30_000;
const AUTHOR_WORK_LIMIT = 5_000;

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

async function fetchFscmWorkMessages(
  baseUrl: string,
  query: string,
  articleIds: string[],
  mode: MessageSearchMode,
): Promise<MessageSearchResult[]> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), getTimeoutMs());
  const route = mode === 'similar' ? 'wsimilar' : 'wcontains';
  const ids = articleIds
    .map((articleId) => Number(articleId))
    .filter((articleId) => Number.isInteger(articleId) && articleId > 0);
  const upstreamUrl = `${baseUrl}/${route}`;

  try {
    const response = await fetch(upstreamUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ids, query }),
      signal: controller.signal,
    });
    if (!response.ok) {
      throw new Error(`fscm returned ${response.status}`);
    }
    const raw = await response.json();
    if (!Array.isArray(raw)) {
      throw new Error('fscm returned an invalid response');
    }
    return raw
      .map((item) => normalizeResult(item as FscmRawResult))
      .filter((item): item is MessageSearchResult => item !== null);
  } finally {
    clearTimeout(timeout);
  }
}

async function fetchGraphWorkSet(
  baseUrl: string,
  articleIds: string[],
): Promise<GraphWorkResponse> {
  const response = await fetch(`${baseUrl}/api/works`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ ids: articleIds }),
  });
  const payload = await response.json().catch(() => null);
  if (!response.ok) {
    const message = typeof (payload as { error?: unknown } | null)?.error === 'string'
      ? (payload as { error: string }).error
      : `violet-graph returned ${response.status}`;
    throw new Error(message);
  }
  return payload as GraphWorkResponse;
}

function findAuthorArticleIds(author: string): string[] {
  const db = getContentDb();
  const rows = db
    .prepare(
      `SELECT Id FROM HitomiColumnModel
       WHERE ExistOnHitomi = 1 AND Artists LIKE ? ESCAPE '\\'
       ORDER BY Id DESC
       LIMIT ?`,
    )
    .all(`%|${escapeLike(author)}|%`, AUTHOR_WORK_LIMIT) as Array<{ Id: number }>;

  return rows.map((row) => String(row.Id));
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

  const results = await fetchFscmWorkMessages(baseUrl, trimmedQuery, articleIds, mode);

  sortMessageResults(results);
  return {
    query: trimmedQuery,
    mode,
    total: results.length,
    results: results.slice(0, limit),
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

  try {
    const articleIds = findAuthorArticleIds(author);
    if (articleIds.length === 0) {
      res.status(404).json({ error: 'Author works not found.' });
      return;
    }

    const work = await fetchGraphWorkSet(graphBaseUrl, articleIds);
    const messages = await searchAuthorMessages(messageBaseUrl, messageQuery, articleIds, 'contains', limit);

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
