import assert from 'node:assert/strict';
import { test } from 'node:test';
import express from 'express';
import { messageSearchRouter, buildFscmSearchUrl } from './message-search.js';

test('mobile status never searches, including while busy; legacy fallback is limited to null or 404', async () => {
  const app = express();
  app.use('/search', messageSearchRouter);
  const server = app.listen(0, '127.0.0.1');
  await new Promise<void>((resolve) => server.once('listening', resolve));
  const { port } = server.address() as { port: number };
  const originalFetch = globalThis.fetch;
  const paths: string[] = [];
  let code = 200;
  let body: unknown = { enabled: true, active: true };
  globalThis.fetch = async (input, options) => {
    const url = new URL(String(input));
    if (url.port === String(port)) return originalFetch(input, options);
    paths.push(url.pathname);
    return url.pathname === '/mobile/status'
      ? new Response(JSON.stringify(body), { status: code }) : new Response('[]');
  };
  try {
    const check = () => fetch(`http://127.0.0.1:${port}/search/status`);
    assert.equal((await check()).status, 200);
    assert.deepEqual(paths.splice(0), ['/mobile/status']);
    for (const legacyCode of [200, 404]) {
      code = legacyCode;
      body = null;
      assert.equal((await check()).status, 200);
      assert.deepEqual(paths.splice(0), ['/mobile/status', '/contains/test']);
    }
    for (const invalidCode of [200, 503]) {
      code = invalidCode;
      body = {};
      assert.equal((await check()).status, 502);
      assert.deepEqual(paths.splice(0), ['/mobile/status']);
    }
  } finally {
    globalThis.fetch = originalFetch;
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});

test('scoped proxy posts exact deduplicated IDs, handles empty scope, and fails closed', async () => {
  const app = express();
  app.use(express.json({ limit: '1mb' }));
  app.use('/search', messageSearchRouter);
  const server = app.listen(0, '127.0.0.1');
  await new Promise<void>((resolve) => server.once('listening', resolve));
  const { port } = server.address() as { port: number };
  const originalFetch = globalThis.fetch;
  const upstream: Array<{ url: string; body: Record<string, unknown>; method: string | undefined }> = [];
  let wrongScope = false;
  globalThis.fetch = async (input, options) => {
    if (new URL(String(input)).port === String(port)) return originalFetch(input, options);
    upstream.push({ url: String(input), body: JSON.parse(String(options?.body)), method: options?.method });
    return new Response(JSON.stringify([{ Id: wrongScope ? 99 : 20, Page: 0, Correctness: 1, MatchScore: 100, Rect: [0, 0, 10, 10] }]));
  };
  const post = (body: unknown) => fetch(`http://127.0.0.1:${port}/search/scoped`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
  });
  try {
    for (const mode of ['contains', 'similar']) {
      const response = await post({ q: 'needle', ids: [20, 10, 20], mode, limit: 1 });
      assert.equal(response.status, 200);
      assert.equal((await response.json()).results[0].articleId, 20);
      const request = upstream.at(-1)!;
      assert.equal(new URL(request.url).pathname, mode === 'similar' ? '/wsimilar/' : '/wcontains/');
      assert.equal(request.method, 'POST');
      assert.deepEqual(request.body, { query: 'needle', ids: [10, 20], limit: 1 });
    }
    const calls = upstream.length;
    assert.deepEqual(await (await post({ q: 'needle', ids: [] })).json(), { query: 'needle', mode: 'contains', total: 0, results: [] });
    for (const ids of [undefined, null, ['20'], [-1], [1.5], [4294967296], Array(50_001).fill(20)]) {
      assert.equal((await post({ q: 'needle', ids })).status, 400);
    }
    assert.equal((await post({ q: 'needle', ids: [20], mode: 'lcs' })).status, 400);
    assert.equal(upstream.length, calls);
    wrongScope = true;
    assert.equal((await post({ q: 'needle', ids: [20] })).status, 502);
  } finally {
    globalThis.fetch = originalFetch;
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});

test('proxy passes bounds to FSCM and rejects invalid ranges before fetching', async () => {
  const app = express();
  app.use('/search', messageSearchRouter);
  const server = app.listen(0, '127.0.0.1');
  await new Promise<void>((resolve) => server.once('listening', resolve));
  const address = server.address() as { port: number };
  const originalFetch = globalThis.fetch;
  const upstream: URL[] = [];
  globalThis.fetch = async (input, options) => {
    const url = new URL(String(input));
    if (url.port === String(address.port)) return originalFetch(input, options);
    upstream.push(url);
    return new Response('[]', { headers: { 'Content-Type': 'application/json' } });
  };
  try {
    const base = `http://127.0.0.1:${address.port}/search?q=test`;
    const response = await fetch(`${base}&idMin=4031374&idMax=4170232&limit=25`);
    assert.equal(response.status, 200);
    assert.equal(upstream[0].searchParams.get('id_min'), '4031374');
    assert.equal(upstream[0].searchParams.get('id_max'), '4170232');
    assert.equal(upstream[0].searchParams.get('limit'), '25');
    for (const query of ['idMin=20&idMax=10', 'idMin=abc', 'idMax=4294967296', 'from=2025-02-30']) {
      assert.equal((await fetch(`${base}&${query}`)).status, 400);
    }
    assert.equal(upstream.length, 1);
    assert.deepEqual(await (await fetch(`${base}&articleId=10&idMin=20`)).json(), {
      query: 'test', mode: 'contains', total: 0, results: [],
    });
    assert.equal(upstream.length, 1);
    const unrestricted = new URL(buildFscmSearchUrl('http://localhost:12332', 'similar', 'a b'));
    assert.equal(unrestricted.searchParams.has('id_min'), false);
  } finally {
    globalThis.fetch = originalFetch;
    await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
});
