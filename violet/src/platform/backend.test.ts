import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import axios, { isAxiosError } from 'axios';
import { createBackend, type Invoke } from './backend';
import { BackendError, createAdapter } from './adapter';
import { dateDistribution } from './dates';

function fixture(respond: (args: Record<string, unknown>) => unknown = () => ({ status: 200, body: [] })) {
  const requests: Record<string, unknown>[] = [];
  const content = new DatabaseSync(':memory:');
  const user = new DatabaseSync(':memory:');
  user.exec(readFileSync(new URL('../../src-tauri/src/user-schema.sql', import.meta.url), 'utf8'));
  content.exec(`CREATE TABLE HitomiColumnModel (Id INTEGER PRIMARY KEY,Title TEXT,Artists TEXT,Tags TEXT,Groups TEXT,Series TEXT,Characters TEXT,Language TEXT,Type TEXT,Files INTEGER,Published TEXT,ExistOnHitomi INTEGER);
    INSERT INTO HitomiColumnModel VALUES (1,'Violet test','|alice|','|landscape|',NULL,NULL,NULL,'korean','manga',12,'2026-09-01',1);
    INSERT INTO HitomiColumnModel VALUES (2,'Other','|bob|','|landscape|',NULL,NULL,NULL,'english','manga',20,'2026-09-03',1);`);
  const invoke: Invoke = async (command, args = {}) => {
    if (command === 'native_message_request') {
      requests.push(args);
      return await respond(args) as any;
    }
    if (command === 'native_query') {
      const db = args.database === 'content' ? content : user;
      return db.prepare(String(args.sql)).all(...args.params as any[]) as any;
    }
    if (command === 'native_execute') {
      user.exec('BEGIN');
      try {
        let id = 0;
        for (const s of args.statements as { sql: string; params: any[] }[]) id = Number(user.prepare(s.sql).run(...s.params).lastInsertRowid);
        user.exec('COMMIT');
        return { Id: id, ok: true } as any;
      } catch (error) { user.exec('ROLLBACK'); throw error; }
    }
    throw new Error(`Unexpected command: ${command}`);
  };
  const api = axios.create({ adapter: createAdapter(createBackend(invoke, params => `local:${params.article}:${params.page}`)) });
  return { api, requests, close: () => { content.close(); user.close(); } };
}

test('message search uses the configured external server and normalizes results', async () => {
  const { api, requests, close } = fixture(() => ({ status: 200, body: [
    { Id: '2', Page: 3, Correctness: 1, Rect: [10, 20, 30, 40], MatchScore: '0.9' },
    { Id: 'invalid' }, null,
  ] }));
  try {
    const { data } = await api.get('/message-search', { params: { baseUrl: 'https://search.example:8443/', q: ' 안녕 / ? ', mode: 'similar', limit: 20 } });
    const url = new URL(String(requests[0].url));
    assert.equal(url.origin, 'https://search.example:8443');
    assert.equal(url.pathname, `/similar/${encodeURIComponent('안녕 / ?')}`);
    assert.equal(url.searchParams.get('limit'), '20');
    assert.equal(requests[0].timeoutMs, 30000);
    assert.equal(requests[0].body, null);
    assert.deepEqual(data, { query: '안녕 / ?', mode: 'similar', total: 1, results: [
      { articleId: 2, page: 3, correctness: 1, rect: [10, 20, 30, 40], matchScore: '0.9' },
    ] });
  } finally { close(); }
});

test('message search converts local dates to external ID bounds and skips empty ranges', async () => {
  const { api, requests, close } = fixture();
  try {
    await api.get('/message-search', { params: { q: 'test', from: '2026-09-03', to: '2026-09-03', articleId: 2 } });
    const url = new URL(String(requests[0].url));
    assert.equal(url.pathname, '/wcontains/2/test');
    assert.equal(url.searchParams.get('id_min'), '2');
    assert.equal(url.searchParams.get('id_max'), '2');
    const empty = await api.get('/message-search', { params: { q: 'test', from: '2027-01-01' } });
    assert.equal(empty.data.total, 0);
    assert.equal(requests.length, 1);
    await assert.rejects(api.get('/message-search', { params: { q: 'test', idMin: 5, idMax: 1 } }), error => isAxiosError(error) && error.response?.status === 400);
    assert.equal(requests.length, 1);
  } finally { close(); }
});

test('scoped message search posts deduplicated IDs and rejects out-of-scope responses', async () => {
  let leak = false;
  const { api, requests, close } = fixture(() => ({ status: 200, body: leak ? [
    { Id: 99, Page: 1, Correctness: 1, Rect: [0, 0, 1, 1] },
  ] : [] }));
  try {
    const body = { baseUrl: 'https://search.example', q: 'test', mode: 'similar', ids: [2, 1, 2], limit: 10 };
    await api.post('/message-search/scoped', body);
    assert.equal(requests[0].url, 'https://search.example/wsimilar/');
    assert.deepEqual(requests[0].body, { ids: [1, 2], query: 'test', limit: 10 });
    leak = true;
    await assert.rejects(api.post('/message-search/scoped', body), error => isAxiosError(error) && error.response?.status === 502);
    await api.post('/message-search/scoped', { ...body, ids: [] });
    assert.equal(requests.length, 2);
  } finally { close(); }
});

test('message search supports mobile status and legacy status fallback', async () => {
  let legacy = false;
  const { api, requests, close } = fixture(args => ({
    status: String(args.url).endsWith('/mobile/status') && legacy ? 404 : 200,
    body: String(args.url).endsWith('/mobile/status') ? (legacy ? null : { enabled: true }) : [],
  }));
  try {
    assert.equal((await api.get('/message-search/status')).data.ok, true);
    assert.equal(requests.length, 1);
    legacy = true;
    assert.equal((await api.get('/message-search/status')).data.sampleCount, 0);
    assert.equal(requests.length, 3);
    assert.equal(requests[2].url, 'http://127.0.0.1:12332/contains/test');
    assert.ok(requests.every(request => request.timeoutMs === 5000));
  } finally { close(); }
});

test('message history stays local, increments counts and escapes wildcard filters', async () => {
  const { api, requests, close } = fixture();
  try {
    await api.post('/message-search/history', { query: '  100%_test  ' });
    await api.post('/message-search/history', { query: '100%_test' });
    await api.post('/message-search/history', { query: '100 other test' });
    const { data } = await api.get('/message-search/history', { params: { q: '%_' } });
    assert.equal(data.items.length, 1);
    assert.equal(data.items[0].query, '100%_test');
    assert.equal(data.items[0].searchCount, 2);
    assert.equal(requests.length, 0);
  } finally { close(); }
});

test('message search reports invalid configuration and unreachable upstream errors', async () => {
  const { api, requests, close } = fixture(() => { throw new Error('Connection refused'); });
  try {
    await assert.rejects(api.get('/message-search', { params: { q: 'test', baseUrl: 'file:///tmp/test' } }), error => isAxiosError(error) && error.response?.status === 400);
    assert.equal(requests.length, 0);
    await assert.rejects(api.get('/message-search', { params: { q: 'test' } }), error => isAxiosError(error) && error.response?.status === 502);
  } finally { close(); }
});

test('shared search DSL filters the local database and preserves batch order', async () => {
  const { api, close } = fixture();
  try {
    const result = await api.get('/content/search', { params: { q: 'artist:alice lang:korean' } });
    assert.equal(result.data.totalCount, 1);
    assert.equal(result.data.articles[0].Id, 1);
    const batch = await api.post('/content/batch', { ids: [2, 1, 999] });
    assert.deepEqual(batch.data.articles.map((row: any) => row.Id), [2, 1]);
  } finally { close(); }
});

test('bookmark and history API contracts work without an HTTP server', async () => {
  const { api, close } = fixture();
  try {
    const group = await api.post('/bookmarks/groups', { Name: 'Test' });
    await api.post('/bookmarks/articles', { Article: '1', GroupId: group.data.Id });
    assert.deepEqual((await api.post('/bookmarks/articles/check', { ids: [1, 2] })).data, { '1': true, '2': false });
    const log = await api.post('/history', { Article: '1', Type: 0 });
    await api.patch(`/history/${log.data.Id}`, { LastPage: 5 });
    assert.equal((await api.get('/history/last-page/1')).data.lastPage, 5);
    assert.equal((await api.get('/history')).data.totalCount, 1);
    await api.delete(`/bookmarks/groups/${group.data.Id}`);
    assert.equal((await api.get('/bookmarks/articles')).data.length, 0);
    await assert.rejects(api.delete('/bookmarks/groups/1'), error => isAxiosError(error) && error.response?.status === 400);
  } finally { close(); }
});

test('unsupported features are explicit errors and do not return fake data', async () => {
  const { api, close } = fixture();
  try {
    await assert.rejects(api.get('/ai-search'), error => isAxiosError(error) && error.response?.status === 501);
  } finally { close(); }
});

test('adapter propagates cancellation, timeout and status errors', async () => {
  const never = axios.create({ adapter: createAdapter(() => new Promise(() => {})) });
  const controller = new AbortController();
  const request = never.get('/test', { signal: controller.signal });
  controller.abort();
  await assert.rejects(request, error => axios.isCancel(error));
  await assert.rejects(never.get('/test', { timeout: 10 }), error => isAxiosError(error) && error.code === 'ECONNABORTED');
  const missing = axios.create({ adapter: createAdapter(async () => { throw new BackendError(404, 'Missing'); }) });
  await assert.rejects(missing.get('/test'), error => isAxiosError(error) && error.response?.status === 404);
});

test('date buckets include gaps, exclusive ends and separate invalid dates', () => {
  const result = dateDistribution([{ start: null, count: 2 }, { start: '2026-09-01', count: 3 }, { start: '2026-09-03', count: 1 }]);
  assert.deepEqual(result.buckets.map(row => row.count), [3, 0, 1]);
  assert.equal(result.buckets[2].end, '2026-09-04');
  assert.equal(result.totalCount, 4);
  assert.equal(result.invalidCount, 2);
});
