import assert from 'node:assert/strict';
import { test } from 'node:test';
import express from 'express';
import Database from 'better-sqlite3';
import { articleStatusHandler } from './article-status.js';

test('batch status preserves membership and completed-only download semantics', async () => {
  const db = new Database(':memory:');
  db.exec(`CREATE TABLE BookmarkArticle (Article TEXT); CREATE TABLE Download (Article TEXT, Status TEXT);
    INSERT INTO BookmarkArticle VALUES ('1'), ('1'), ('2');
    INSERT INTO Download VALUES ('1','completed'), ('2','downloading'), ('3','failed');`);
  const app = express();
  app.use(express.json());
  app.post('/bookmark', articleStatusHandler(() => db, 'bookmark'));
  app.post('/download', articleStatusHandler(() => db, 'download'));
  const server = app.listen(0, '127.0.0.1');
  await new Promise<void>((resolve) => server.once('listening', resolve));
  const { port } = server.address() as { port: number };
  const request = (kind: string, ids: unknown) => fetch(`http://127.0.0.1:${port}/${kind}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ ids }),
  });
  try {
    assert.deepEqual(await (await request('bookmark', ['1','2','3','1'])).json(), { 1: true, 2: true, 3: false });
    assert.deepEqual(await (await request('download', ['1','2','3'])).json(), { 1: true, 2: false, 3: false });
    db.exec("DELETE FROM BookmarkArticle WHERE Article='1'");
    assert.deepEqual(await (await request('bookmark', ['1'])).json(), { 1: false });
    assert.deepEqual(await (await request('bookmark', [])).json(), {});
    assert.equal((await request('bookmark', Array(201).fill('1'))).status, 400);
    assert.equal((await request('bookmark', [1])).status, 400);
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
    db.close();
  }
});
