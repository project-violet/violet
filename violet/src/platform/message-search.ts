import type { MessageSearchResult } from '@violet-web/shared';
import { normalizedPublishedSql, parseDateBounds } from '../../../violet-web/packages/backend/src/services/publication-date';
import { parseArticleIdBound } from '../../../violet-web/packages/backend/src/services/message-search-range';
import { BackendError, type Request } from './adapter';
import type { Invoke } from './backend';

function bad(message: string): never { throw new BackendError(400, message); }
function normalizeResult(raw: unknown): MessageSearchResult | null {
  if (!raw || typeof raw !== 'object') return null;
  const row = raw as Record<string, unknown>;
  const articleId = Number(row.Id), page = Number(row.Page), correctness = Number(row.Correctness);
  if (![articleId, page, correctness].every(Number.isFinite) || !Array.isArray(row.Rect) || row.Rect.length !== 4) return null;
  const rect = row.Rect.map(Number);
  if (!rect.every(Number.isFinite)) return null;
  return { articleId, page, correctness, rect: rect as MessageSearchResult['rect'],
    matchScore: typeof row.MatchScore === 'number' || typeof row.MatchScore === 'string' ? row.MatchScore : '' };
}

export function createMessageSearch(invoke: Invoke) {
  const query = (database: 'content' | 'user', sql: string, params: unknown[] = []) =>
    invoke<Record<string, any>[]>('native_query', { database, sql, params });
  const request = async (url: URL, body?: unknown, statusCheck = false) => {
    try {
      return await invoke<{ status: number; body: unknown }>('native_message_request', {
        url: url.toString(), body: body ?? null, timeoutMs: statusCheck ? 5000 : 30000,
      });
    } catch (error) { throw new BackendError(502, `Failed to reach message search server: ${String(error)}`); }
  };
  const responseBody = (response: { status: number; body: unknown }) => {
    if (response.status < 200 || response.status >= 300) throw new BackendError(502, `Message search server returned ${response.status}`);
    return response.body;
  };
  return async ({ method, path, params: p, body: b }: Request) => {
    if (path === '/message-search/history') {
      if (method === 'POST') {
        const text = typeof b.query === 'string' ? b.query.trim() : '';
        if (!text) bad('Search query is required');
        await invoke('native_execute', { statements: [{
          sql: `INSERT INTO MessageSearchHistory (Query,SearchCount,LastSearchedAt) VALUES (?,1,?)
            ON CONFLICT(Query) DO UPDATE SET SearchCount=SearchCount+1, LastSearchedAt=excluded.LastSearchedAt`,
          params: [text, new Date().toISOString()],
        }] });
        return { ok: true };
      }
      if (method !== 'GET') bad('Unsupported message search method');
      const text = (p.q ?? '').trim();
      const values: (string | number)[] = text ? [`%${text.replace(/[\\%_]/g, '\\$&')}%`] : [];
      const parsed = parseInt(p.limit);
      const hasLimit = Number.isFinite(parsed);
      if (hasLimit) values.push(Math.max(1, Math.min(5000, parsed)));
      return { items: await query('user', `SELECT Query as query, SearchCount as searchCount, LastSearchedAt as lastSearchedAt
        FROM MessageSearchHistory ${text ? "WHERE Query COLLATE NOCASE LIKE ? ESCAPE '\\'" : ''}
        ORDER BY LastSearchedAt DESC${hasLimit ? ' LIMIT ?' : ''}`, values) };
    }

    const input = method === 'POST' ? b : p;
    let baseUrl: string;
    try {
      const url = new URL(typeof input.baseUrl === 'string' && input.baseUrl.trim() ? input.baseUrl.trim() : 'http://127.0.0.1:12332');
      if (!['http:', 'https:'].includes(url.protocol)) throw new Error();
      baseUrl = url.origin;
    } catch { return bad('Invalid message search server URL'); }
    if (path === '/message-search/status' && method === 'GET') {
      const response = await request(new URL('/mobile/status', baseUrl), undefined, true);
      if (response.status !== 404) {
        const status = responseBody(response);
        if (status && typeof status === 'object' && 'enabled' in status && status.enabled === true) return { ok: true, baseUrl };
        if (status !== null) throw new BackendError(502, 'Invalid message search server status');
      }
      const sample = responseBody(await request(new URL('/contains/test', baseUrl), undefined, true));
      if (!Array.isArray(sample)) throw new BackendError(502, 'Invalid message search server response');
      return { ok: true, baseUrl, sampleCount: sample.length };
    }
    const scoped = path === '/message-search/scoped' && method === 'POST';
    if (!scoped && !(path === '/message-search' && method === 'GET')) bad('Unsupported message search route');
    const text = typeof input.q === 'string' ? input.q.trim() : '';
    const mode = input.mode ?? 'contains';
    if (!text || !['contains', 'similar', 'lcs'].includes(String(mode))) bad('Invalid search query or mode');
    const limit = scoped ? Number(input.limit ?? 100) : Math.max(1, Math.min(500, parseInt(String(input.limit)) || 100));
    const empty = { query: text, mode, total: 0, results: [] };
    let scope: number[] | undefined;
    let url: URL;
    let body: unknown;
    if (scoped) {
      if (mode === 'lcs' || !Number.isInteger(limit) || limit < 1 || limit > 500 || !Array.isArray(input.ids)
        || input.ids.length > 50000 || input.ids.some(id => typeof id !== 'number' || !Number.isInteger(id) || id < 0 || id > 0xffffffff)) bad('Invalid article scope');
      scope = [...new Set(input.ids as number[])].sort((a, b) => a - b);
      if (!scope.length) return empty;
      url = new URL(mode === 'similar' ? '/wsimilar/' : '/wcontains/', baseUrl);
      body = { ids: scope, query: text, limit };
    } else {
      const articleId = (p.articleId ?? '').trim();
      if (articleId && (!/^\d+$/.test(articleId) || mode === 'lcs')) bad('Invalid work-scoped search');
      let idMin: number | undefined, idMax: number | undefined;
      try {
        idMin = parseArticleIdBound(p.idMin); idMax = parseArticleIdBound(p.idMax);
        const dates = parseDateBounds(p.from, p.to);
        if ((idMin ?? 0) > (idMax ?? 0xffffffff)) bad('Reversed article ID range');
        if (dates.from || dates.toExclusive) {
          const conditions = ['ExistOnHitomi = 1']; const values: string[] = [];
          if (dates.from) { conditions.push(`${normalizedPublishedSql()} >= ?`); values.push(dates.from); }
          if (dates.toExclusive) { conditions.push(`${normalizedPublishedSql()} < ?`); values.push(dates.toExclusive); }
          const [row] = await query('content', `SELECT MIN(Id) AS idMin, MAX(Id) AS idMax FROM HitomiColumnModel WHERE ${conditions.join(' AND ')}`, values);
          if (!row || row.idMin === null || row.idMax === null) return empty;
          idMin = Math.max(idMin ?? 0, row.idMin); idMax = Math.min(idMax ?? 0xffffffff, row.idMax);
        }
      } catch (error) { throw new BackendError(400, error instanceof Error ? error.message : String(error)); }
      if ((idMin ?? 0) > (idMax ?? 0xffffffff) || (articleId && (Number(articleId) < (idMin ?? 0) || Number(articleId) > (idMax ?? 0xffffffff)))) return empty;
      const route = articleId ? `${mode === 'similar' ? 'wsimilar' : 'wcontains'}/${encodeURIComponent(articleId)}` : mode;
      url = new URL(`/${route}/${encodeURIComponent(text)}`, baseUrl);
      url.searchParams.set('limit', String(limit));
      if (idMin !== undefined) url.searchParams.set('id_min', String(idMin));
      if (idMax !== undefined) url.searchParams.set('id_max', String(idMax));
    }
    const raw = responseBody(await request(url, body));
    if (!Array.isArray(raw)) throw new BackendError(502, 'Invalid message search server response');
    const results = raw.map(normalizeResult).filter((result): result is MessageSearchResult => result !== null);
    if (scope) {
      const allowed = new Set(scope);
      if (results.some(result => !allowed.has(result.articleId))) throw new BackendError(502, 'Message search server ignored article scope');
    }
    return { query: text, mode, total: results.length, results: results.slice(0, limit) };
  };
}
