import assert from 'node:assert/strict';
import { test } from 'node:test';
import { buildLocalDateDistribution, filterItemsByDateRange } from './local-date-range-model.js';

test('builds a daily distribution from ISO and SQLite timestamps', () => {
  const distribution = buildLocalDateDistribution([
    '2026-07-01T10:00:00.000Z',
    '2026-07-01 12:00:00.000',
    '2026-07-03T09:00:00.000Z',
  ]);

  assert.equal(distribution.minDate, '2026-07-01');
  assert.equal(distribution.maxDate, '2026-07-03');
  assert.equal(distribution.totalCount, 3);
  assert.equal(distribution.unit, 'day');
  assert.deepEqual(distribution.buckets.map((bucket) => bucket.count), [2, 0, 1]);
});

test('filters items by inclusive local date bounds', () => {
  const items = [
    { id: 1, date: '2026-07-01T10:00:00.000Z' },
    { id: 2, date: '2026-07-02 12:00:00.000' },
    { id: 3, date: '2026-07-03T09:00:00.000Z' },
  ];

  assert.deepEqual(
    filterItemsByDateRange(items, (item) => item.date, '2026-07-02', '2026-07-03')
      .map((item) => item.id),
    [2, 3],
  );
});
