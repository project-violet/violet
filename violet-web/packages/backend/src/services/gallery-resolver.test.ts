import assert from 'node:assert/strict';
import { test } from 'node:test';
import { resolveGallery } from './gallery-resolver.js';

test('concurrent galleries share script refresh and same-ID fetches; failures can retry', async () => {
  const originalFetch = globalThis.fetch;
  const counts = new Map<string, number>();
  let failGallery = false;
  globalThis.fetch = async (input) => {
    const url = String(input);
    counts.set(url, (counts.get(url) ?? 0) + 1);
    if (url.endsWith('/gg.js')) return new Response("var gg = { m: function() { return 1; }, b: 'cdn', s: function() {} };");
    if (url.includes('hitomi_get_image_list_v4_model.js')) return new Response(`
      function create_download_url(id) { return 'https://gallery.test/' + id; }
      function hitomi_get_header_content() { return '{}'; }
      function hitomi_get_image_list() { return JSON.stringify({result: ['image-' + galleryId], btresult: [], stresult: []}); }
    `);
    if (url.startsWith('https://gallery.test/')) {
      if (failGallery) return new Response('failed', { status: 503 });
      return new Response('var galleryId = ' + Number(url.split('/').pop()) + ';');
    }
    throw new Error(`Unexpected test URL: ${url}`);
  };
  try {
    const results = await Promise.all(Array.from({ length: 20 }, (_, i) => resolveGallery(i < 10 ? 10 : 20)));
    assert.equal(counts.get('https://ltn.gold-usergeneratedcontent.net/gg.js'), 1);
    assert.equal([...counts.keys()].filter((key) => key.includes('v4_model')).reduce((n, key) => n + counts.get(key)!, 0), 1);
    assert.equal(counts.get('https://gallery.test/10'), 1);
    assert.equal(counts.get('https://gallery.test/20'), 1);
    assert.deepEqual(results[0], { urls: ['image-10'], bigThumbnails: [], smallThumbnails: [] });
    results[0].urls.push('caller-only');
    assert.deepEqual(results[1].urls, ['image-10']);
    failGallery = true;
    const failures = await Promise.allSettled([resolveGallery(30), resolveGallery(30)]);
    assert.ok(failures.every((result) => result.status === 'rejected'));
    assert.equal(counts.get('https://gallery.test/30'), 1);
    failGallery = false;
    assert.deepEqual((await resolveGallery(30)).urls, ['image-30']);
    assert.equal(counts.get('https://gallery.test/30'), 2);
    // Completed results are not cached: later calls retain the old freshness behavior.
    await resolveGallery(10);
    assert.equal(counts.get('https://gallery.test/10'), 2);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
