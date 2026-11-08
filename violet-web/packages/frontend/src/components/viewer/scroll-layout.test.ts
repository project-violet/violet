import assert from 'node:assert/strict';
import { test } from 'node:test';
import { captureAnchor, pageAtOffset, restoreAnchor, validDimensions } from './scroll-layout';

function boxes(heights: number[]) {
  return (page: number) => ({ top: heights.slice(0, page).reduce((a, b) => a + b, 0), height: heights[page] });
}

test('tracks a long page even when less than half of it fits on screen', () => {
  const box = boxes([1200, 8000, 1200]);
  assert.equal(pageAtOffset(3, box, 4800), 1);
  assert.equal(pageAtOffset(3, box, 9200), 2);
});

test('loading pages above the reading position preserves the same point', () => {
  const anchor = captureAnchor(3, boxes([1000, 1000, 1000]), 1100, 600, 3000);
  assert.equal(restoreAnchor(anchor, boxes([1800, 1000, 1000]), 600, 3800), 1900);
});

test('late dimensions preserve relative position within the visible page', () => {
  const anchor = captureAnchor(3, boxes([1000, 1000, 1000]), 1100, 600, 3000);
  assert.equal(restoreAnchor(anchor, boxes([1000, 2000, 1000]), 600, 4000), 1410);
});

test('scrolling to the end before images load stays at the end', () => {
  const anchor = captureAnchor(3, boxes([1000, 1000, 1000]), 2400, 600, 3000);
  assert.equal(restoreAnchor(anchor, boxes([1800, 1600, 2000]), 600, 5400), 4800);
});

test('missing, invalid, and zero dimensions use the fallback layout', () => {
  for (const size of [null, undefined, { width: 0, height: 10 }, { width: Infinity, height: 10 }, { width: 10, height: -1 }]) {
    assert.equal(validDimensions(size), false);
  }
  assert.equal(validDimensions({ width: 1200, height: 1800 }), true);
});
