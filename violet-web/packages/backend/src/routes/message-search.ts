import { Router } from 'express';
import type {
  MessageSearchHistoryResponse,
  MessageSearchMode,
  MessageSearchResponse,
  MessageSearchResult,
  MessageSearchStatusResponse,
} from '@violet-web/shared';
import { getUserDb } from '../services/user-db.js';

export const messageSearchRouter = Router();

const MODES = new Set<MessageSearchMode>(['contains', 'similar', 'lcs']);
const DEFAULT_FSCM_BASE_URL = 'http://127.0.0.1:12332';
const DEFAULT_TIMEOUT_MS = 30_000;
const STATUS_TIMEOUT_MS = 5_000;

interface FscmRawResult {
  Id?: unknown;
  Page?: unknown;
  Correctness?: unknown;
  MatchScore?: unknown;
  Rect?: unknown;
}

function normalizeBaseUrl(raw: unknown): string | null {
  const value = typeof raw === 'string' && raw.trim()
    ? raw.trim()
    : process.env.FSCM_BASE_URL || DEFAULT_FSCM_BASE_URL;

  try {
    const url = new URL(value);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return null;
    return url.origin;
  } catch {
    return null;
  }
}

function getTimeoutMs(statusCheck = false): number {
  if (statusCheck) return STATUS_TIMEOUT_MS;
  const parsed = Number(process.env.FSCM_TIMEOUT_MS);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : DEFAULT_TIMEOUT_MS;
}

async function fetchFscm(
  baseUrl: string,
  mode: MessageSearchMode,
  query: string,
  statusCheck = false,
): Promise<unknown> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), getTimeoutMs(statusCheck));
  const upstreamUrl = `${baseUrl}/${mode}/${encodeURIComponent(query)}`;

  try {
    const response = await fetch(upstreamUrl, { signal: controller.signal });
    if (!response.ok) {
      throw new Error(`fscm returned ${response.status}`);
    }
    return await response.json();
  } finally {
    clearTimeout(timeout);
  }
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

function escapeLike(value: string): string {
  return value.replace(/[\\%_]/g, (match) => `\\${match}`);
}

messageSearchRouter.get('/history', (req, res) => {
  const q = ((req.query.q as string) || '').trim();
  const parsedLimit = parseInt(req.query.limit as string);
  const limit = Number.isFinite(parsedLimit)
    ? Math.max(1, Math.min(5_000, parsedLimit))
    : null;
  const db = getUserDb();

  const baseSql = `SELECT Query as query, SearchCount as searchCount, LastSearchedAt as lastSearchedAt
    FROM MessageSearchHistory`;
  const whereSql = q ? ` WHERE Query COLLATE NOCASE LIKE ? ESCAPE '\\'` : '';
  const limitSql = limit === null ? '' : ' LIMIT ?';
  const params = q ? [`%${escapeLike(q)}%`] : [];
  if (limit !== null) params.push(String(limit));

  const rows = db
    .prepare(`${baseSql}${whereSql} ORDER BY LastSearchedAt DESC${limitSql}`)
    .all(...params);

  const response: MessageSearchHistoryResponse = {
    items: rows as MessageSearchHistoryResponse['items'],
  };
  res.json(response);
});

messageSearchRouter.post('/history', (req, res) => {
  const query = typeof req.body?.query === 'string' ? req.body.query.trim() : '';

  if (!query) {
    res.status(400).json({ error: 'Request body "query" is required.' });
    return;
  }

  const db = getUserDb();
  const now = new Date().toISOString();
  db.prepare(
    `INSERT INTO MessageSearchHistory (Query, SearchCount, LastSearchedAt)
     VALUES (?, 1, ?)
     ON CONFLICT(Query) DO UPDATE SET
       SearchCount = SearchCount + 1,
       LastSearchedAt = excluded.LastSearchedAt`,
  ).run(query, now);

  res.json({ ok: true });
});

messageSearchRouter.get('/', async (req, res) => {
  const q = ((req.query.q as string) || '').trim();
  const mode = ((req.query.mode as string) || 'contains') as MessageSearchMode;
  const limit = Math.max(1, Math.min(500, parseInt(req.query.limit as string) || 100));
  const baseUrl = normalizeBaseUrl(req.query.baseUrl);

  if (!q) {
    res.status(400).json({ error: 'Query parameter "q" is required.' });
    return;
  }

  if (!MODES.has(mode)) {
    res.status(400).json({ error: 'Invalid message search mode.' });
    return;
  }

  if (!baseUrl) {
    res.status(400).json({ error: 'Invalid fscm baseUrl.' });
    return;
  }

  try {
    const raw = await fetchFscm(baseUrl, mode, q);

    if (!Array.isArray(raw)) {
      res.status(502).json({ error: 'fscm returned an invalid response.' });
      return;
    }

    const results = raw
      .map((item) => normalizeResult(item as FscmRawResult))
      .filter((item): item is MessageSearchResult => item !== null);

    const response: MessageSearchResponse = {
      query: q,
      mode,
      total: results.length,
      results: results.slice(0, limit),
    };

    res.json(response);
  } catch (error) {
    console.error('Message search proxy error:', error);
    res.status(502).json({ error: 'Failed to reach fscm search server.' });
  }
});

messageSearchRouter.get('/status', async (req, res) => {
  const baseUrl = normalizeBaseUrl(req.query.baseUrl);

  if (!baseUrl) {
    res.status(400).json({ ok: false, baseUrl: '', error: 'Invalid fscm baseUrl.' });
    return;
  }

  try {
    const raw = await fetchFscm(baseUrl, 'contains', 'test', true);
    if (!Array.isArray(raw)) {
      const response: MessageSearchStatusResponse = {
        ok: false,
        baseUrl,
        error: 'fscm returned an invalid response.',
      };
      res.status(502).json(response);
      return;
    }

    const response: MessageSearchStatusResponse = {
      ok: true,
      baseUrl,
      sampleCount: raw.length,
    };
    res.json(response);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    const response: MessageSearchStatusResponse = {
      ok: false,
      baseUrl,
      error: message,
    };
    res.status(502).json(response);
  }
});
