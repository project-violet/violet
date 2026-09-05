import assert from 'node:assert/strict';
import { test } from 'node:test';
import { BoundedCache } from './bounded-cache.js';

test('expired entries are discarded and replacement does not evict unrelated entries', () => {
  const cache = new BoundedCache<{ ts: number; value: number }>(2);
  cache.set('old', { ts: Date.now() - 60_001, value: 0 });
  cache.set('a', { ts: Date.now(), value: 1 });
  assert.equal(cache.has('old'), false);
  cache.set('b', { ts: Date.now(), value: 2 });
  cache.set('a', { ts: Date.now(), value: 3 });
  assert.equal(cache.get('b')?.value, 2);
  cache.set('c', { ts: Date.now(), value: 4 });
  assert.equal(cache.size, 2);
  assert.equal(cache.has('b'), false);
  assert.equal(cache.get('a')?.value, 3);
});
