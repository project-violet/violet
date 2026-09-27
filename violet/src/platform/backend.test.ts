import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import axios, { isAxiosError } from 'axios';
import { createBackend, type Invoke } from './backend';
import { BackendError, createAdapter } from './adapter';
import { dateDistribution } from './dates';

function fixture() {
  const content = new DatabaseSync(':memory:');
  const user = new DatabaseSync(':memory:');
  user.exec(readFileSync(new URL('../../src-tauri/src/user-schema.sql', import.meta.url), 'utf8'));
  content.exec(`CREATE TABLE HitomiColumnModel (Id INTEGER PRIMARY KEY,Title TEXT,Artists TEXT,Tags TEXT,Groups TEXT,Series TEXT,Characters TEXT,Language TEXT,Type TEXT,Files INTEGER,Published TEXT,ExistOnHitomi INTEGER);
    INSERT INTO HitomiColumnModel VALUES (1,'Violet test','|alice|','|landscape|',NULL,NULL,NULL,'korean','manga',12,'2026-09-01',1);
    INSERT INTO HitomiColumnModel VALUES (2,'Other','|bob|','|landscape|',NULL,NULL,NULL,'english','manga',20,'2026-09-03',1);`);
  const invoke: Invoke = async (command, args = {}) => {
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
  return { api, close: () => { content.close(); user.close(); } };
}

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
