import { translateQuery, translateQueryCondition } from '../../../violet-web/packages/backend/src/services/query-engine';
import { normalizedPublishedSql } from '../../../violet-web/packages/backend/src/services/publication-date';
import type { Article, ImageList, TagEntry } from '@violet-web/shared';
import { BackendError, type Request } from './adapter';
import { dateDistribution } from './dates';

export type Invoke = <T>(command: string, args?: Record<string, unknown>) => Promise<T>;
type Row = Record<string, any>;
type Scalar = string | number | boolean | null;

export function createBackend(invoke: Invoke, mediaUrl: (params: Record<string, string>) => string) {
  const query = <T = Row>(database: 'content' | 'user', sql: string, params: Scalar[] = []) =>
    invoke<T[]>('native_query', { database, sql, params });
  const mutate = (sql: string, params: Scalar[] = []) =>
    invoke('native_execute', { statements: [{ sql, params }] });
  const count = async (database: 'content' | 'user', sql: string, params: Scalar[] = []) =>
    Number((await query(database, sql, params))[0]?.cnt ?? 0);
  const positive = (input: unknown, fallback: number, max = Number.MAX_SAFE_INTEGER) => {
    const n = Number(input);
    return Number.isSafeInteger(n) && n >= 0 ? Math.min(n, max) : fallback;
  };
  let tagPromise: Promise<TagEntry[]> | undefined;
  let ftsPromise: Promise<boolean> | undefined;
  let lastRevision: string | null = null;
  const tags = () => tagPromise ??= invoke<TagEntry[]>('native_tags', { condition: null, refresh: false }).catch((error) => { tagPromise = undefined; throw error; });
  const hasFts = () => ftsPromise ??= count('content', "SELECT COUNT(*) AS cnt FROM sqlite_master WHERE name IN ('FtsTitle','FtsTags')").then(n => n === 2).catch(() => { ftsPromise = undefined; return false; });
  const getGallery = async (id: number): Promise<ImageList> => {
    const local = await query('user', "SELECT TotalPages FROM Download WHERE Article=? AND Status='completed' ORDER BY Id DESC LIMIT 1", [String(id)]);
    if (local[0]?.TotalPages > 0) {
      const urls = Array.from({ length: Number(local[0].TotalPages) }, (_, page) => mediaUrl({ article: String(id), page: String(page) }));
      return { urls, bigThumbnails: urls.slice(0, 1), smallThumbnails: urls.slice(0, 1) };
    }
    return invoke<ImageList>('native_gallery', { id });
  };

  return async function dispatch({ method, path, params: p, body: b }: Request): Promise<unknown> {
    const page = positive(p.page, 0);
    const pageSize = Math.max(1, positive(p.pageSize, 30, 100));
    const limit = Math.max(1, positive(p.limit, 20, 100));
    const now = () => new Date().toISOString();
    const id = positive(path.split('/').at(-1), 0);
    const required = (value: unknown): string => {
      if (typeof value !== 'string' || !value.trim()) throw new BackendError(400, 'A non-empty value is required');
      return value;
    };
    const scalar = (value: unknown, fallback: Scalar = null): Scalar =>
      typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean' ? value : fallback;

    if (path === '/sync/status') {
      const status = await invoke<{ lastSync: string | null }>('native_status');
      if (status.lastSync !== lastRevision) { lastRevision = status.lastSync; tagPromise = undefined; ftsPromise = undefined; }
      return status;
    }
    if (method === 'POST' && ['/sync/trigger', '/sync/full'].includes(path)) {
      await invoke('native_sync');
      return { message: 'Database update started' };
    }

    if (method === 'GET' && path === '/content/search') {
      const run = async (fts: boolean) => {
        const sql = translateQuery(p.q ?? '', page, pageSize, fts, { from: p.from, to: p.to });
        const [articles, totalCount] = await Promise.all([query<Article>('content', sql.sql), count('content', sql.countSql)]);
        return { articles, totalCount, page, pageSize };
      };
      const fts = await hasFts();
      try { return await run(fts); } catch (error) { if (!fts) throw error; return run(false); }
    }
    if (method === 'POST' && path === '/content/batch') {
      const ids = (Array.isArray(b.ids) ? b.ids : []).filter((v): v is number => Number.isSafeInteger(v) && Number(v) > 0).slice(0, 5000);
      if (!ids.length) return { articles: [] };
      const rows = await query<Article>('content', `SELECT * FROM HitomiColumnModel WHERE Id IN (${ids.map(() => '?').join(',')})`, ids);
      const map = new Map(rows.map(row => [row.Id, row]));
      return { articles: ids.map(id => map.get(id)).filter(Boolean) };
    }
    if (path === '/content/search/tags') {
      const result = await invoke<TagEntry[]>('native_tags', { condition: translateQueryCondition(p.q ?? ''), refresh: false });
      return { tags: result.slice(0, limit) };
    }
    if (path === '/content/search/date-distribution') {
      const dates = await query<{ start: string | null; count: number }>('content', `SELECT substr(${normalizedPublishedSql()},1,10) AS start, COUNT(*) AS count FROM HitomiColumnModel WHERE ${translateQueryCondition(p.q ?? '')} GROUP BY start ORDER BY start`);
      return dateDistribution(dates);
    }
    if (path.startsWith('/content/suggest')) {
      if (path.endsWith('/rebuild')) {
        tagPromise = invoke<TagEntry[]>('native_tags', { condition: null, refresh: true });
        await tagPromise;
        return { success: true };
      }
      const all = await tags();
      if (path.endsWith('/tag-counts')) return Object.fromEntries(all.filter(t => ['female', 'male', 'tag'].includes(t.category)).map(t => [t.display, t.count]));
      if (path.endsWith('/status')) {
        const counts: Record<string, number> = {};
        for (const tag of all) counts[tag.category] = (counts[tag.category] ?? 0) + 1;
        return { built: true, counts };
      }
      const search = (p.q ?? '').toLowerCase().replaceAll('_', ' ').trim();
      if (!search) return { suggestions: [] };
      const matches = all.filter(tag => `${tag.category}:${tag.tag}`.toLowerCase().includes(search));
      if (path.endsWith('/contextual') && p.base) {
        const suggestions = await Promise.all(matches.slice(0, Math.min(limit * 5, 100)).map(async tag => ({ ...tag,
          contextualCount: await count('content', `SELECT COUNT(*) AS cnt FROM HitomiColumnModel WHERE ${translateQueryCondition(`${p.base} ${tag.display}`)}`),
        })));
        return { suggestions: suggestions.filter(t => t.contextualCount > 0).sort((a, b) => b.contextualCount - a.contextualCount).slice(0, limit) };
      }
      return { suggestions: matches.slice(0, limit) };
    }
    if (method === 'GET' && /^\/content\/\d+$/.test(path)) {
      const rows = await query('content', 'SELECT * FROM HitomiColumnModel WHERE Id=?', [id]);
      if (!rows.length) throw new BackendError(404, 'Article not found');
      return rows[0];
    }
    if (path.startsWith('/proxy/gallery/')) return getGallery(id);
    if (path.startsWith('/proxy/thumbnail/')) {
      const images = await getGallery(id);
      if (!images.bigThumbnails.length) throw new BackendError(404, 'Thumbnail not found');
      return { url: images.bigThumbnails[0] };
    }

    if (path === '/bookmarks/groups') {
      if (method === 'GET') return query('user', 'SELECT * FROM BookmarkGroup ORDER BY Gorder');
      if (method === 'POST') return mutate('INSERT INTO BookmarkGroup (Name,DateTime,Description,Color,Gorder) VALUES (?,?,?,?,(SELECT COALESCE(MAX(Gorder),0)+1 FROM BookmarkGroup))', [required(b.Name), now(), scalar(b.Description), scalar(b.Color)]);
    }
    if (method === 'DELETE' && /^\/bookmarks\/groups\/\d+$/.test(path)) {
      if (id === 1) throw new BackendError(400, 'The default group cannot be deleted');
      return invoke('native_execute', { statements: [
        { sql: 'DELETE FROM BookmarkArticle WHERE GroupId=?', params: [id] },
        { sql: 'DELETE FROM BookmarkArtist WHERE GroupId=?', params: [id] },
        { sql: 'DELETE FROM BookmarkGroup WHERE Id=?', params: [id] },
      ] });
    }
    if (path === '/bookmarks/articles/check' || path === '/downloads/check') {
      const ids = (Array.isArray(b.ids) ? b.ids : []).map(String).slice(0, 5000);
      if (!ids.length) return {};
      const table = path.startsWith('/bookmarks') ? 'BookmarkArticle' : 'Download';
      const rows = await query('user', `SELECT DISTINCT Article FROM ${table} WHERE Article IN (${ids.map(() => '?').join(',')})${table === 'Download' ? " AND Status='completed'" : ''}`, ids);
      const exists = new Set(rows.map(row => row.Article));
      return Object.fromEntries(ids.map(id => [id, exists.has(id)]));
    }
    for (const [route, table] of [['articles', 'BookmarkArticle'], ['artists', 'BookmarkArtist'], ['crops', 'BookmarkCropImage']] as const) {
      if (path === `/bookmarks/${route}`) {
        if (method === 'GET') return query('user', `SELECT * FROM ${table}${route !== 'crops' && p.groupId !== undefined ? ' WHERE GroupId=?' : ''} ORDER BY Id DESC`, route !== 'crops' && p.groupId !== undefined ? [positive(p.groupId, 1)] : []);
        if (method === 'POST') {
          if (route === 'articles') return mutate('INSERT INTO BookmarkArticle (Article,DateTime,GroupId) VALUES (?,?,?)', [required(b.Article), now(), scalar(b.GroupId, 1)]);
          if (route === 'artists') return mutate('INSERT INTO BookmarkArtist (Artist,IsGroup,DateTime,GroupId) VALUES (?,?,?,?)', [required(b.Artist), scalar(b.IsGroup, 0), now(), scalar(b.GroupId, 1)]);
          return mutate('INSERT INTO BookmarkCropImage (Article,Page,Area,AspectRatio,DateTime) VALUES (?,?,?,?,?)', [scalar(b.Article), scalar(b.Page), required(b.Area), scalar(b.AspectRatio), now()]);
        }
      }
      if (method === 'DELETE' && new RegExp(`^/bookmarks/${route}/\\d+$`).test(path)) return mutate(`DELETE FROM ${table} WHERE Id=?`, [id]);
    }

    if (path === '/history') {
      if (method === 'GET') {
        const logs = await query('user', 'SELECT * FROM (SELECT *,ROW_NUMBER() OVER (PARTITION BY Article ORDER BY Id DESC) AS rn FROM ArticleReadLog) WHERE rn=1 ORDER BY Id DESC LIMIT ? OFFSET ?', [pageSize, page * pageSize]);
        return { logs, totalCount: await count('user', 'SELECT COUNT(DISTINCT Article) AS cnt FROM ArticleReadLog'), page, pageSize };
      }
      if (method === 'POST') return mutate('INSERT INTO ArticleReadLog (Article,DateTimeStart,LastPage,Type) VALUES (?,?,0,?)', [required(b.Article), now(), scalar(b.Type, 0)]);
    }
    if (path === '/history/ids' || path === '/downloads/ids') {
      const history = path.startsWith('/history');
      const entries = await query('user', `SELECT Article AS articleId, MAX(${history ? 'DateTimeStart' : 'DateTime'}) AS date FROM ${history ? 'ArticleReadLog' : 'Download'}${history ? '' : " WHERE Status='completed'"} GROUP BY Article ORDER BY date DESC`);
      return { entries, articleIds: entries.map(row => row.articleId) };
    }
    if (path.startsWith('/history/last-page/')) {
      const rows = await query('user', 'SELECT LastPage FROM ArticleReadLog WHERE Article=? AND LastPage>0 ORDER BY Id DESC LIMIT 1', [String(id)]);
      return { lastPage: rows[0]?.LastPage ?? null };
    }
    if (/^\/history\/\d+$/.test(path)) {
      if (method === 'PATCH') return mutate('UPDATE ArticleReadLog SET LastPage=?,DateTimeEnd=? WHERE Id=?', [scalar(b.LastPage, 0), scalar(b.DateTimeEnd, now()), id]);
      if (method === 'DELETE') return mutate('DELETE FROM ArticleReadLog WHERE Id=?', [id]);
    }

    if (path === '/downloads/completed-ids') return { ids: (await query('user', "SELECT DISTINCT Article FROM Download WHERE Status='completed'")).map(row => Number(row.Article)) };
    if (path === '/downloads') {
      if (method === 'POST') return invoke('native_download', { article: positive(b.articleId, 0) });
      const downloads = await query('user', 'SELECT * FROM Download ORDER BY Id DESC LIMIT ? OFFSET ?', [pageSize, page * pageSize]);
      return { downloads, totalCount: await count('user', 'SELECT COUNT(*) AS cnt FROM Download'), page, pageSize };
    }
    if (/^\/downloads\/\d+\/retry$/.test(path) && method === 'POST') {
      const row = (await query('user', 'SELECT Article FROM Download WHERE Id=?', [Number(path.split('/')[2])]))[0];
      if (!row) throw new BackendError(404, 'Download not found');
      return invoke('native_download', { article: Number(row.Article) });
    }
    if (/^\/downloads\/\d+$/.test(path)) {
      if (method === 'DELETE') { await invoke('native_delete_download', { id }); return { ok: true }; }
      const rows = await query('user', 'SELECT * FROM Download WHERE Id=?', [id]);
      if (!rows.length) throw new BackendError(404, 'Download not found');
      return rows[0];
    }
    throw new BackendError(501, `This feature is not yet available in the native app: ${method} ${path}`);
  };
}
