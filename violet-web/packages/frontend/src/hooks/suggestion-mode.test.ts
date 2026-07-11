import assert from 'node:assert/strict';
import { test } from 'node:test';
import { shouldUseContextualSuggestions } from './suggestion-mode.js';

test('uses regular suggestions when contextual counts are disabled', () => {
  assert.equal(shouldUseContextualSuggestions(false, 'artist:mi', 'lang:korean'), false);
});

test('uses contextual suggestions only when enabled with a search context', () => {
  assert.equal(shouldUseContextualSuggestions(true, 'artist:mi', 'lang:korean'), true);
  assert.equal(shouldUseContextualSuggestions(true, 'artist:mi', ''), false);
});