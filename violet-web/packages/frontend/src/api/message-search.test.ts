import assert from 'node:assert/strict';
import { test } from 'node:test';
import { api } from './client.js';
import { messageSearch } from './message-search.js';

test('requires backend acknowledgement of work conditions instead of displaying global results', async () => {
  const original = api.defaults.adapter;
  let supported = false;
  api.defaults.adapter = async (config) => {
    assert.equal(config.params.articleQuery, 'lang:korean');
    return { config, status: 200, statusText: 'OK', headers: {},
      data: { query: 'needle', mode: 'contains', results: [], total: 0,
        ...(supported ? { articleQuery: 'lang:korean' } : {}) } };
  };
  try {
    await assert.rejects(messageSearch('needle', 'contains', 100, undefined, undefined, { articleQuery: 'lang:korean' }),
      (error: unknown) => (error as { code?: string }).code === 'FILTER_UNSUPPORTED');
    supported = true;
    assert.equal((await messageSearch('needle', 'contains', 100, undefined, undefined, { articleQuery: 'lang:korean' })).articleQuery, 'lang:korean');
  } finally { api.defaults.adapter = original; }
});
