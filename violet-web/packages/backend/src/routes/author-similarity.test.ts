import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  buildLatestAuthorWorksQuery,
  normalizeContentLanguage,
} from './author-similarity.js';

test('normalizes supported content language filters', () => {
  assert.equal(normalizeContentLanguage('korean'), 'korean');
  assert.equal(normalizeContentLanguage('all'), null);
  assert.equal(normalizeContentLanguage(''), null);
  assert.equal(normalizeContentLanguage('spanish'), null);
});

test('builds latest author works query with language filter', () => {
  const query = buildLatestAuthorWorksQuery(['healthy_man'], 5, 'korean');

  assert.match(query.sql, /Language = \?/);
  assert.deepEqual(query.params, ['%|healthy\\_man|%', 'korean', 5]);
});

test('builds latest author works query without language filter for all languages', () => {
  const query = buildLatestAuthorWorksQuery(['healthy_man'], 5, null);

  assert.doesNotMatch(query.sql, /Language = \?/);
  assert.deepEqual(query.params, ['%|healthy\\_man|%', 5]);
});
