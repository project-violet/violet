import assert from 'node:assert/strict';
import { test } from 'node:test';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import Database from 'better-sqlite3';
import express from 'express';
import { messageSearchRouter } from './message-search.js';
import { closeContentDb } from '../services/content-db.js';

test('tag-filtered requests POST DB IDs before top-k and fail closed', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'violet-tags-'));
  const oldPath = process.env.DATA_DB_PATH;
  process.env.DATA_DB_PATH = join(dir, 'data.db');
  const db = new Database(process.env.DATA_DB_PATH);
  db.exec(`CREATE TABLE HitomiColumnModel (Id INTEGER PRIMARY KEY, Title TEXT, ExistOnHitomi INTEGER, Language TEXT, Files INTEGER, Published TEXT);
    INSERT INTO HitomiColumnModel VALUES (10, 'a', 1, 'korean', 120, '2025-01-10'), (20, 'b', 1, 'english', 120, '2025-01-10'), (30, 'c', 1, 'korean', 130, '2025-02-10');`);
  db.close();
  const app = express();
  app.use('/search', messageSearchRouter);
  const server = app.listen(0, '127.0.0.1');
  await new Promise<void>(resolve => server.once('listening', resolve));
  const port = (server.address() as { port: number }).port;
  const originalFetch = globalThis.fetch;
  const upstream: Array<{ url: string; options?: RequestInit }> = [];
  let wrong = false;
  globalThis.fetch = async (input, options) => {
    if (new URL(String(input)).port === String(port)) return originalFetch(input, options);
    upstream.push({ url: String(input), options });
    return new Response(JSON.stringify([{ Id: wrong ? 99 : JSON.parse(String(options?.body)).ids[0], Page: 0, Correctness: 1, MatchScore: 100, Rect: [0, 0, 1, 1] }]));
  };
  const query = 'lang:korean page>100';
  const get = (params: Record<string, string>) => fetch(`http://127.0.0.1:${port}/search?${new URLSearchParams({ q: 'needle', ...params })}`);
  try {
    for (const mode of ['contains', 'similar']) {
      const response = await get({ articleQuery: query, mode, from: '2025-01-01', to: '2025-01-31', limit: '1' });
      assert.equal(response.status, 200);
      assert.equal((await response.json()).articleQuery, query);
      const call = upstream.at(-1)!;
      assert.equal(new URL(call.url).pathname, mode === 'contains' ? '/wcontains/' : '/wsimilar/');
      assert.equal(call.options?.method, 'POST');
      assert.deepEqual(JSON.parse(String(call.options?.body)), { query: 'needle', ids: [10], limit: 1 });
    }
    const calls = upstream.length;
    assert.deepEqual(await (await get({ articleQuery: 'lang:missing' })).json(), { query: 'needle', mode: 'contains', total: 0, results: [], articleQuery: 'lang:missing' });
    assert.equal((await get({ articleQuery: query, mode: 'lcs' })).status, 400);
    assert.equal((await get({ articleQuery: 'page>' })).status, 400);
    assert.equal(upstream.length, calls);
    const writer = new Database(process.env.DATA_DB_PATH!);
    writer.exec(`WITH RECURSIVE ids(n) AS (SELECT 100 UNION ALL SELECT n+1 FROM ids WHERE n<50100)
      INSERT INTO HitomiColumnModel (Id, ExistOnHitomi, Language) SELECT n, 1, 'broad' FROM ids;`);
    writer.close();
    const broad = await get({ articleQuery: 'lang:broad' });
    assert.equal(broad.status, 200);
    assert.equal((await broad.json()).articleQuery, 'lang:broad');
    const forwarded = JSON.parse(String(upstream.at(-1)!.options?.body)).ids;
    assert.equal(forwarded.length, 50_001);
    assert.equal(forwarded.at(-1), 50_100);
    assert.equal(upstream.length, calls + 1);
    wrong = true;
    assert.equal((await get({ articleQuery: query })).status, 502);
  } finally {
    globalThis.fetch = originalFetch;
    closeContentDb();
    if (oldPath === undefined) delete process.env.DATA_DB_PATH; else process.env.DATA_DB_PATH = oldPath;
    await new Promise<void>(resolve => server.close(() => resolve()));
    rmSync(dir, { recursive: true, force: true });
  }
});
