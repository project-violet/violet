import assert from 'node:assert/strict';
import { test } from 'node:test';
import { filterActivityPeriod } from './activity-period.js';

test('filters by calendar days from the latest activity instead of active-day count', () => {
  const days = [
    { date: '2025-01-01', total: 1 },
    { date: '2026-04-01', total: 1 },
    { date: '2026-06-29', total: 1 },
  ];
  assert.deepEqual(filterActivityPeriod(days, 90).map((day) => day.date), ['2026-04-01', '2026-06-29']);
  assert.deepEqual(filterActivityPeriod(days, 0), days);
});
