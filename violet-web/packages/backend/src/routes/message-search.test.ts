import assert from 'node:assert/strict';
import { test } from 'node:test';
import express from 'express';
import { messageSearchRouter, buildFscmSearchUrl } from './message-search.js';

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
