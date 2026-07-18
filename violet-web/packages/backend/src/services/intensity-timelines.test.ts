import assert from 'node:assert/strict';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { test } from 'node:test';
import { IntensityTimelineStore } from './intensity-timelines.js';

test('indexes JSONL offsets and reads one normalized timeline', async () => {
  const directory = await mkdtemp(path.join(os.tmpdir(), 'violet-intensity-'));
  const filePath = path.join(directory, 'timelines.jsonl');
  const metadata = { type: 'metadata', schema_version: 1 };
  const timeline = {
    work_id: 42,
    page_count: 3,
    raw: [0, 50, 100],
    smooth: [10, 50, 90],
    peaks: [[3, 90]],
    interpolated_ranges: [[1, 1]],
  };
  await writeFile(
    filePath,
    `${JSON.stringify(metadata)}\n${JSON.stringify(timeline)}\n`,
    'utf8',
  );

  const store = new IntensityTimelineStore(filePath);
  try {
    assert.deepEqual(await store.get(42), {
      workId: 42,
      pageCount: 3,
      raw: [0, 50, 100],
      smooth: [10, 50, 90],
      peaks: [[3, 90]],
      interpolatedRanges: [[1, 1]],
    });
    assert.equal(await store.get(99), null);
    assert.deepEqual(await store.status(), {
      available: true,
      indexedWorks: 1,
      fileSize: Buffer.byteLength(`${JSON.stringify(metadata)}\n${JSON.stringify(timeline)}\n`),
    });
  } finally {
    await store.close();
    await rm(directory, { recursive: true, force: true });
  }
});
