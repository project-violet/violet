import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  buildSmoothAreaPath,
  clampRange,
  dateToDayOffset,
  dayOffsetToDate,
  estimateSelectedCount,
  updateDateParams,
} from './date-range-model.js';

test('distribution renders as one continuous area path', () => {
  const path = buildSmoothAreaPath([0, 10, 5], 100, 20);
  assert.match(path, /^M 0 20 L 0 20 C /);
  assert.match(path, /L 100 20 Z$/);
  assert.equal((path.match(/ C /g) ?? []).length, 2);
});

test('thumbs cannot cross', () => {
  assert.deepEqual(clampRange(8, 4, 0, 10, 'from'), [4, 4]);
  assert.deepEqual(clampRange(8, 4, 0, 10, 'to'), [8, 8]);
});

test('dates round-trip through smooth day offsets', () => {
  const offset = dateToDayOffset('2007-05-17', '2025-06-15');
  assert.equal(dayOffsetToDate('2007-05-17', offset), '2025-06-15');
});

test('selected count is proportionally estimated inside coarse buckets', () => {
  assert.equal(estimateSelectedCount([
    { start: '2025-01-01', end: '2026-01-01', count: 365 },
  ], '2025-06-01', '2025-06-30'), 30);
});

test('full available range preserves the exact bucket count', () => {
  assert.equal(estimateSelectedCount([
    { start: '2026-01-01', end: '2027-01-01', count: 191 },
  ], '2026-01-01', '2026-07-10', '2026-01-01', '2026-07-10'), 191);
});

test('committing bounds resets pagination and preserves the query', () => {
  const params = updateDateParams(
    new URLSearchParams('q=artist:test&p=4'),
    '2024-01-01',
    '2025-12-31',
  );
  assert.equal(
    params.toString(),
    'q=artist%3Atest&from=2024-01-01&to=2025-12-31',
  );
});

test('reset removes both bounds', () => {
  const params = updateDateParams(
    new URLSearchParams('q=test&from=2020-01-01&to=2021-01-01'),
    undefined,
    undefined,
  );
  assert.equal(params.toString(), 'q=test');
});
