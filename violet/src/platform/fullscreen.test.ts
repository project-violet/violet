import assert from 'node:assert/strict';
import test from 'node:test';
import { createViewerFullscreen } from './fullscreen';

function viewportFixture() {
  const viewport = { content: 'width=device-width, initial-scale=1.0' };
  const doc = { querySelector: () => viewport } as unknown as Document;
  return { viewport, doc };
}

test('serializes delayed native enter/exit and restores viewport on exit', async () => {
  const { viewport, doc } = viewportFixture();
  const original = viewport.content;
  const calls: boolean[] = [];
  let release!: () => void;
  const first = new Promise<void>(resolve => { release = resolve; });
  const setFullscreen = createViewerFullscreen(async (_command, { enabled }) => {
    calls.push(enabled);
    if (calls.length === 1) await first;
    return true;
  }, doc);
  const transitions = [setFullscreen(true), setFullscreen(false), setFullscreen(true)];
  await Promise.resolve();
  assert.deepEqual(calls, [true]);
  release();
  await Promise.all(transitions);
  assert.deepEqual(calls, [true, false, true]);
  assert.equal(viewport.content, `${original}, viewport-fit=cover`);
  await setFullscreen(false);
  assert.equal(viewport.content, original);
});

test('unsupported platforms keep their original viewport', async () => {
  const { viewport, doc } = viewportFixture();
  const original = viewport.content;
  await createViewerFullscreen(async () => false, doc)(true);
  assert.equal(viewport.content, original);
});

test('a failed native transition does not block the next transition', async () => {
  const { viewport, doc } = viewportFixture();
  let calls = 0;
  const setFullscreen = createViewerFullscreen(async () => {
    if (++calls === 1) throw new Error('transition failed');
    return true;
  }, doc);
  await assert.rejects(setFullscreen(true), /transition failed/);
  await setFullscreen(true);
  assert.match(viewport.content, /viewport-fit=cover/);
});
