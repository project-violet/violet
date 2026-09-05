import assert from 'node:assert/strict';
import { test } from 'node:test';
import { Writable } from 'node:stream';
import type { Response as ExpressResponse } from 'express';
import { proxyImage } from './image-proxy.js';

test('slow receivers exert backpressure without changing image bytes or headers', async () => {
  const originalFetch = globalThis.fetch;
  let produced = 0;
  let received = 0;
  let release: (() => void) | undefined;
  let firstWrite!: () => void;
  const started = new Promise<void>((resolve) => { firstWrite = resolve; });
  const headers = new Map<string, unknown>();
  const response = Object.assign(new Writable({
    highWaterMark: 1024,
    write(chunk, _encoding, callback) {
      received += chunk.length;
      assert.ok(chunk.every((byte: number) => byte === 7));
      if (!release) { release = callback; firstWrite(); } else callback();
    },
  }), { setHeader: (key: string, value: unknown) => headers.set(key, value) });
  globalThis.fetch = async () => new Response(new ReadableStream({
    pull(controller) {
      if (produced === 64) { controller.close(); return; }
      produced++;
      controller.enqueue(new Uint8Array(65536).fill(7));
    },
  }), { headers: { 'Content-Type': 'image/webp', 'Content-Length': String(64 * 65536) } });
  try {
    const transfer = proxyImage('https://example.test/image', undefined, response as unknown as ExpressResponse);
    await started;
    await new Promise<void>((resolve) => setImmediate(resolve));
    assert.ok(produced < 64, 'must stop pulling while response buffer is full');
    release!();
    await transfer;
    assert.equal(received, 64 * 65536);
    assert.equal(headers.get('Content-Type'), 'image/webp');
    assert.equal(headers.get('Cache-Control'), 'public, max-age=86400');
  } finally { globalThis.fetch = originalFetch; response.destroy(); }
});

test('receiver disconnect aborts an upstream request still waiting for headers', async () => {
  const originalFetch = globalThis.fetch;
  const response = new Writable({ write(_chunk, _encoding, callback) { callback(); } });
  let aborted = false;
  globalThis.fetch = async (_input, options) => new Promise((_resolve, reject) => {
    options!.signal!.addEventListener('abort', () => { aborted = true; reject(new Error('aborted')); }, { once: true });
  });
  try {
    const transfer = proxyImage('https://example.test/image', undefined, response as unknown as ExpressResponse);
    response.destroy();
    await assert.rejects(transfer, /aborted/);
    assert.equal(aborted, true);
    assert.equal(response.listenerCount('close'), 0);
  } finally { globalThis.fetch = originalFetch; }
});
