import assert from 'node:assert/strict';
import { test } from 'node:test';
import fs from 'node:fs';
import vm from 'node:vm';

const expression = fs.readFileSync(new URL('../../scripts/gallery_image_list_with_dimensions.js', import.meta.url), 'utf8');

test('returns index-aligned dimensions without downloading any image', () => {
  const context = vm.createContext({
    galleryinfo: { files: [{ width: '800', height: 1200 }, { width: 0, height: 12 }, { width: 1600, height: 800 }] },
    hitomi_get_image_list: () => JSON.stringify({ result: ['a', 'b', 'c', 'd'], btresult: [], stresult: [] }),
  });
  assert.deepEqual(JSON.parse(vm.runInContext(expression, context)).dimensions,
    [{ width: 800, height: 1200 }, null, { width: 1600, height: 800 }, null]);
});

test('older resolver metadata without files remains readable', () => {
  const context = vm.createContext({ hitomi_get_image_list: () => JSON.stringify({ result: ['a'], btresult: [], stresult: [] }) });
  assert.deepEqual(JSON.parse(vm.runInContext(expression, context)).dimensions, [null]);
});
