import assert from 'node:assert/strict';
import { test } from 'node:test';
import { translateQuery } from './query-engine.js';

test('adds inclusive normalized publication bounds', () => {
  const translated = translateQuery('lang:korean', 0, 30, false, {
    from: '2025-01-01',
    to: '2025-12-31',
  });
  assert.match(translated.sql, />= '2025-01-01 00:00:00'/);
  assert.match(translated.sql, /< '2026-01-01 00:00:00'/);
});

test('leaves legacy SQL unchanged without bounds', () => {
  assert.doesNotMatch(translateQuery('', 0, 30).sql, /datetime\(/);
});
