import assert from 'node:assert/strict';
import test from 'node:test';
import { createViewerFullscreen } from './fullscreen';

function viewportFixture() {
  let content = 'width=device-width, initial-scale=1.0';
  const writes: string[] = [];
  const viewport = {
    get content() { return content; },
    set content(value: string) { content = value; writes.push(value); },
  };
  const dataset: Record<string, string> = {};
  const doc = { querySelector: () => viewport, documentElement: { dataset } } as unknown as Document;
  return { viewport, doc, writes, dataset };
}

test('serializes delayed native enter/exit without resizing the viewport again', async () => {
  const { viewport, doc, writes, dataset } = viewportFixture();
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
  assert.deepEqual(writes, [`${original}, viewport-fit=cover`]);
  assert.equal(dataset.nativeIos, 'true');
});

test('initial non-viewer route establishes the same viewport used by the reader', async () => {
  const { viewport, doc, writes } = viewportFixture();
  const setFullscreen = createViewerFullscreen(async () => true, doc);
  await setFullscreen(false);
  const initialViewport = viewport.content;
  await setFullscreen(true);
  await setFullscreen(false);
  assert.match(initialViewport, /viewport-fit=cover/);
  assert.deepEqual(writes, [initialViewport]);
});

test('unsupported platforms keep their original viewport', async () => {
  const { viewport, doc, writes, dataset } = viewportFixture();
  const original = viewport.content;
  await createViewerFullscreen(async () => false, doc)(true);
  assert.equal(viewport.content, original);
  assert.deepEqual(writes, []);
  assert.deepEqual(dataset, {});
});

test('theme changes keep the requested reader mode and leave the viewport stable', async () => {
  const { doc, dataset, writes } = viewportFixture();
  let themeChanged!: () => void;
  Object.defineProperty(doc, 'defaultView', { value: {
    MutationObserver: class {
      constructor(callback: () => void) { themeChanged = callback; }
      observe() {}
    },
  } });
  const calls: { enabled: boolean; dark: boolean }[] = [];
  const setFullscreen = createViewerFullscreen(async (_command, args) => {
    calls.push(args);
    return true;
  }, doc);
  await setFullscreen(false);
  await setFullscreen(true);
  dataset.theme = 'light';
  themeChanged();
  // A subsequent exit must run after the queued appearance update.
  await setFullscreen(false);
  assert.deepEqual(calls, [
    { enabled: false, dark: true },
    { enabled: true, dark: true },
    { enabled: true, dark: false },
    { enabled: false, dark: false },
  ]);
  assert.equal(writes.length, 1);
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
