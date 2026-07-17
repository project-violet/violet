import { Router } from 'express';
import type {
  LlmSearchHistoryResponse,
  LlmSearchResponse,
  LlmSearchResult,
  LlmSearchStatusResponse,
} from '@violet-web/shared';
import { getUserDb } from '../services/user-db.js';

export const llmSearchRouter = Router();

const DEFAULT_BASE_URL = 'http://127.0.0.1:8788';
const DEFAULT_TIMEOUT_MS = 5 * 60_000;
const STATUS_TIMEOUT_MS = 5_000;
const MAX_TOP_K = 100;
const MAX_CANDIDATE_K = 1_000;

interface RawLlmResult {
  rank?: unknown;
  rerank_score?: unknown;
  embed_score?: unknown;
  work?: unknown;
  pages?: unknown;
}

interface RawLlmResponse {
  elapsed_ms?: unknown;
  results?: unknown;
}

function isLoopbackUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return url.hostname === 'localhost' || url.hostname === '127.0.0.1' || url.hostname === '::1';
  } catch {
    return false;
  }
}

function normalizeBaseUrl(raw: unknown): string | null {
  const configured = process.env.LLM_SEARCH_BASE_URL?.trim();
  const requested = typeof raw === 'string' && raw.trim() ? raw.trim() : '';
  const value = configured && (!requested || isLoopbackUrl(requested))
    ? configured
    : requested || DEFAULT_BASE_URL;

  try {
    const url = new URL(value);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return null;
    return url.origin;
  } catch {
    return null;
  }
}

function timeoutMs(statusCheck = false): number {
  if (statusCheck) return STATUS_TIMEOUT_MS;
  const parsed = Number(process.env.LLM_SEARCH_TIMEOUT_MS);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : DEFAULT_TIMEOUT_MS;
}

async function fetchJson(
  url: string,
  init: RequestInit,
  statusCheck = false,
): Promise<unknown> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs(statusCheck));
  try {
    const response = await fetch(url, { ...init, signal: controller.signal });
    const payload = await response.json().catch(() => null);
    if (!response.ok) {
      const detail = payload && typeof payload === 'object' && 'detail' in payload
        ? String((payload as { detail: unknown }).detail)
        : `HTTP ${response.status}`;
      throw new Error(`LLM search returned ${detail}`);
    }
    return payload;
  } finally {
    clearTimeout(timeout);
  }
}

function finiteNumber(value: unknown): number | null {
  const number = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(number) ? number : null;
}

function normalizeResult(raw: RawLlmResult): LlmSearchResult | null {
  const rank = finiteNumber(raw.rank);
  const embedScore = finiteNumber(raw.embed_score);
  const work = finiteNumber(raw.work);
  const rerankScore = raw.rerank_score === null ? null : finiteNumber(raw.rerank_score);
  if (
    rank === null
    || embedScore === null
    || work === null
    || (raw.rerank_score !== null && rerankScore === null)
  ) return null;
  if (!Array.isArray(raw.pages)) return null;
  const pages = raw.pages.map(finiteNumber);
  if (pages.length === 0 || pages.some((page) => page === null)) return null;
  return {
    rank,
    rerankScore,
    embedScore,
    work,
    pages: pages as number[],
  };
}

function escapeLike(value: string): string {
  return value.replace(/[\\%_]/g, (match) => `\\${match}`);
}

function parseCount(value: unknown, fallback: number, maximum: number): number {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? Math.min(parsed, maximum) : fallback;
}

llmSearchRouter.get('/history', (req, res) => {
  const q = ((req.query.q as string) || '').trim();
  const parsedLimit = Number(req.query.limit);
  const limit = Number.isInteger(parsedLimit) ? Math.max(1, Math.min(5_000, parsedLimit)) : null;
  const params: Array<string | number> = q ? [`%${escapeLike(q)}%`] : [];
  if (limit !== null) params.push(limit);
  const rows = getUserDb().prepare(
    `SELECT Query as query, TopK as topK, CandidateK as candidateK,
            SearchCount as searchCount, LastSearchedAt as lastSearchedAt
       FROM LlmSearchHistory
      ${q ? "WHERE Query COLLATE NOCASE LIKE ? ESCAPE '\\'" : ''}
      ORDER BY LastSearchedAt DESC
      ${limit === null ? '' : 'LIMIT ?'}`,
  ).all(...params);
  const response: LlmSearchHistoryResponse = {
    items: rows as LlmSearchHistoryResponse['items'],
  };
  res.json(response);
});

llmSearchRouter.post('/history', (req, res) => {
  const query = typeof req.body?.query === 'string' ? req.body.query.trim() : '';
  const topK = parseCount(req.body?.topK, 10, MAX_TOP_K);
  const candidateK = parseCount(req.body?.candidateK, 500, MAX_CANDIDATE_K);
  if (!query || candidateK < topK) {
    res.status(400).json({ error: 'Valid query, topK, and candidateK are required.' });
    return;
  }
  const now = new Date().toISOString();
  getUserDb().prepare(
    `INSERT INTO LlmSearchHistory (Query, TopK, CandidateK, SearchCount, LastSearchedAt)
     VALUES (?, ?, ?, 1, ?)
     ON CONFLICT(Query) DO UPDATE SET
       TopK = excluded.TopK,
       CandidateK = excluded.CandidateK,
       SearchCount = SearchCount + 1,
       LastSearchedAt = excluded.LastSearchedAt`,
  ).run(query, topK, candidateK, now);
  res.json({ ok: true });
});

llmSearchRouter.post('/', async (req, res) => {
  const query = typeof req.body?.query === 'string' ? req.body.query.trim() : '';
  const topK = parseCount(req.body?.topK, 10, MAX_TOP_K);
  const candidateK = parseCount(req.body?.candidateK, 500, MAX_CANDIDATE_K);
  const baseUrl = normalizeBaseUrl(req.body?.baseUrl);
  if (!query) {
    res.status(400).json({ error: 'Request body "query" is required.' });
    return;
  }
  if (candidateK < topK) {
    res.status(400).json({ error: 'candidateK must be at least topK.' });
    return;
  }
  if (!baseUrl) {
    res.status(400).json({ error: 'Invalid LLM search baseUrl.' });
    return;
  }

  try {
    const raw = await fetchJson(`${baseUrl}/v1/search`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        query,
        top_k: topK,
        candidate_k: candidateK,
        rerank: true,
        include_messages: false,
      }),
    }) as RawLlmResponse;
    if (!raw || !Array.isArray(raw.results)) {
      res.status(502).json({ error: 'LLM search returned an invalid response.' });
      return;
    }
    const results = raw.results
      .map((item) => normalizeResult(item as RawLlmResult))
      .filter((item): item is LlmSearchResult => item !== null);
    const response: LlmSearchResponse = {
      query,
      topK,
      candidateK,
      elapsedMs: finiteNumber(raw.elapsed_ms) ?? 0,
      total: results.length,
      results,
    };
    res.json(response);
  } catch (error) {
    console.error('LLM search proxy error:', error);
    res.status(502).json({ error: error instanceof Error ? error.message : 'Failed to reach LLM search server.' });
  }
});

llmSearchRouter.get('/status', async (req, res) => {
  const baseUrl = normalizeBaseUrl(req.query.baseUrl);
  if (!baseUrl) {
    res.status(400).json({ ok: false, baseUrl: '', error: 'Invalid LLM search baseUrl.' });
    return;
  }
  try {
    const raw = await fetchJson(`${baseUrl}/health`, { method: 'GET' }, true) as Record<string, unknown>;
    const response: LlmSearchStatusResponse = {
      ok: raw?.status === 'ok',
      baseUrl,
      works: finiteNumber(raw?.works) ?? undefined,
      vectors: finiteNumber(raw?.vectors) ?? undefined,
      dimensions: finiteNumber(raw?.dimensions) ?? undefined,
    };
    res.status(response.ok ? 200 : 502).json(response);
  } catch (error) {
    const response: LlmSearchStatusResponse = {
      ok: false,
      baseUrl,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
    res.status(502).json(response);
  }
});
