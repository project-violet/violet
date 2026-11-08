import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { Article } from '@violet-web/shared';
import { filterLocalArticles } from './local-article-search.js';

function article(Id: number, Files: number | null, overrides: Partial<Article> = {}): Article {
  return {
    Id, Files, Title: 'Sample title', EHash: null, Type: 'manga',
    Artists: '|sample artist|', Characters: null, Groups: null,
    Language: 'korean', Series: null, Tags: '|female:sample tag|',
    Uploader: null, Published: null, Class: null, PublishedEH: null,
    Thumbnail: null, URL: null, ExistOnHitomi: 1, ...overrides,
  };
}

const articles = [article(1, 99), article(2, 100), article(3, 101), article(4, null)];
const ids = (query: string) => filterLocalArticles(articles, query).map(a => a.Id);

test('page comparisons respect strict and inclusive boundaries and exclude unknown counts', () => {
  assert.deepEqual(ids('page>100'), [3]);
  assert.deepEqual(ids('page>=100'), [2, 3]);
  assert.deepEqual(ids('page<100'), [1]);
  assert.deepEqual(ids('page<=100'), [1, 2]);
  assert.deepEqual(ids('page=100'), [2]);
  assert.deepEqual(ids('page==100'), [2]);
});

test('combines page ranges with existing tag, field and title searches', () => {
  const items = [
    article(1, 120), article(2, 200), article(3, 201),
    article(4, 150, { Language: 'english' }),
    article(5, 150, { Artists: '|other artist|' }),
    article(6, 150, { Title: 'Different work' }),
    article(7, 150, { Tags: null }),
  ];
  assert.deepEqual(
    filterLocalArticles(items, 'page>100 page<=200 lang:korean artist:sample_artist female:sample_tag title')
      .map(a => a.Id),
    [1, 2],
  );
  assert.deepEqual(filterLocalArticles(items, 'page>200 page<100'), []);
});

test('zero is a known page count and empty queries preserve the input', () => {
  const items = [article(1, 0), article(2, null)];
  assert.deepEqual(filterLocalArticles(items, 'page=0').map(a => a.Id), [1]);
  assert.deepEqual(filterLocalArticles(items, 'page<=0').map(a => a.Id), [1]);
  assert.strictEqual(filterLocalArticles(items, '  '), items);
});

test('requires a complete page expression and preserves plain text matching', () => {
  const items = [article(1, 101), article(2, 1, { Title: 'page>100extra' })];
  assert.deepEqual(filterLocalArticles(items, 'page>100extra').map(a => a.Id), [2]);
  assert.deepEqual(filterLocalArticles(items, 'page>>100'), []);
  assert.deepEqual(ids('SAMPLE artist:sample_artist'), [1, 2, 3, 4]);
});
