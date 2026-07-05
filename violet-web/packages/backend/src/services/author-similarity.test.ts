import assert from 'node:assert/strict';
import { mkdir, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { test } from 'node:test';
import {
  findAuthorSimilarityFromFile,
  normalizeAuthorSimilarityKey,
} from './author-similarity.js';

test('normalizes author search keys like the author work export', () => {
  assert.equal(normalizeAuthorSimilarityKey('Healthy_Man  '), 'healthy man');
  assert.equal(normalizeAuthorSimilarityKey('  Foo   Bar '), 'foo bar');
});

test('finds a searched author and returns similar authors from generated JSON', async () => {
  const dir = path.join(tmpdir(), `author-similarity-${Date.now()}`);
  await mkdir(dir, { recursive: true });
  const filePath = path.join(dir, 'author_similarity.json');
  await writeFile(
    filePath,
    JSON.stringify({
      generated_at: '2026-07-05T00:00:00Z',
      params: { top_n: 20 },
      author_count: 2,
      keyword_count: 3,
      authors: [
        {
          author_key: 'healthy man',
          author_name: 'healthy_man',
          work_count: 32,
          matched_work_count: 30,
          keyword_count: 100,
          similar_authors: [
            {
              author_key: 'peer artist',
              author_name: 'peer_artist',
              work_count: 11,
              score: 0.75,
              shared_keyword_count: 4,
              shared_keywords: [{ keyword: 'alpha', score: 2.5 }],
            },
          ],
        },
      ],
    }),
    'utf8',
  );

  const result = await findAuthorSimilarityFromFile(filePath, 'healthy_man', 5);

  assert.ok(result);
  assert.equal(result.target.authorKey, 'healthy man');
  assert.equal(result.target.authorName, 'healthy_man');
  assert.equal(result.similarAuthors.length, 1);
  assert.equal(result.similarAuthors[0].authorKey, 'peer artist');
  assert.equal(result.similarAuthors[0].sharedKeywords[0].keyword, 'alpha');
});
