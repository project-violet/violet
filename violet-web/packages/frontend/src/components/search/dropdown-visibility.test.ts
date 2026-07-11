import assert from 'node:assert/strict';
import { test } from 'node:test';
import { shouldShowSearchDropdown } from './dropdown-visibility.js';

test('keeps a populated dropdown visible while a replacement suggestion request is loading', () => {
  assert.equal(shouldShowSearchDropdown(true, 20, true, true, true), true);
});

test('hides the dropdown only for the first suggestion request with no results yet', () => {
  assert.equal(shouldShowSearchDropdown(true, 10, true, false, true), false);
  assert.equal(shouldShowSearchDropdown(true, 0, false, false, true), false);
});