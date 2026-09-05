import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createStatusBatcher } from './batch-status.js';

test('coalesces duplicate IDs, splits large batches, and fetches fresh state later', async () => {
  const calls: string[][] = [];
  let state = true;
  const check = createStatusBatcher(async (ids) => {
    calls.push(ids);
    return Object.fromEntries(ids.map((id) => [id, state]));
  });
  const values = await Promise.all([...Array.from({ length: 401 }, (_, id) => check(String(id))), check('0')]);
  assert.equal(values.length, 402);
  assert.ok(values.every(Boolean));
  assert.deepEqual(calls.map((ids) => ids.length), [200, 200, 1]);
  state = false;
  assert.equal(await check('0'), false);
});

test('all callers receive a batch failure and a subsequent retry succeeds', async () => {
  let fail = true;
  const check = createStatusBatcher(async () => {
    if (fail) throw new Error('offline');
    return { a: true };
  });
  const results = await Promise.allSettled([check('a'), check('b')]);
  assert.ok(results.every((result) => result.status === 'rejected'));
  fail = false;
  assert.equal(await check('a'), true);
});
