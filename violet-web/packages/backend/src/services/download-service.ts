import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { getUserDb } from './user-db.js';
import { resolveGallery, getGalleryHeaders } from './gallery-resolver.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ARTICLES_DIR = path.resolve(__dirname, '../../data/articles');

const USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

const MAX_RETRIES = 100;
const RETRY_DELAY_MS = 500;

async function fetchWithRetry(
  url: string,
  headers: Record<string, string>,
  tag: string,
  pageIndex: number,
): Promise<Response> {
  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    const res = await fetch(url, { headers });
    if (res.ok) return res;

    // Don't retry 4xx (except 429)
    if (res.status >= 400 && res.status < 500 && res.status !== 429) {
      throw new Error(`Failed to fetch page ${pageIndex}: HTTP ${res.status}`);
    }

    if (attempt === MAX_RETRIES) {
      throw new Error(`Failed to fetch page ${pageIndex}: HTTP ${res.status} after ${MAX_RETRIES} retries`);
    }

    console.warn(`${tag} Page ${pageIndex} HTTP ${res.status}, retry ${attempt}/${MAX_RETRIES} in ${RETRY_DELAY_MS}ms`);
    await new Promise((r) => setTimeout(r, RETRY_DELAY_MS));
  }

  throw new Error('Unreachable');
}

function getExtFromUrl(url: string): string {
  const pathname = new URL(url).pathname;
  const ext = path.extname(pathname);
  return ext || '.jpg';
}

/**
 * Mark any downloads left in 'downloading' state as 'failed'.
 * Should be called once at server startup.
 */
export function recoverInterruptedDownloads(): void {
  const db = getUserDb();
  const result = db
    .prepare("UPDATE Download SET Status = 'failed', ErrorMessage = 'Server restarted during download' WHERE Status = 'downloading'")
    .run();
  if (result.changes > 0) {
    console.log(`[download] Recovered ${result.changes} interrupted download(s) to failed state`);
  }
}

export async function startDownload(articleId: string): Promise<number> {
  const db = getUserDb();

  const result = db
    .prepare(
      'INSERT INTO Download (Article, Status, TotalPages, DownloadedPages, DateTime) VALUES (?, ?, 0, 0, ?)',
    )
    .run(articleId, 'downloading', new Date().toISOString());

  const downloadId = Number(result.lastInsertRowid);

  // Fire-and-forget: run the actual download in the background
  processDownload(downloadId, articleId).catch(() => {});

  return downloadId;
}

export async function retryDownload(downloadId: number): Promise<void> {
  const db = getUserDb();
  const record = db.prepare('SELECT * FROM Download WHERE Id = ?').get(downloadId) as
    | { Id: number; Article: string; Status: string }
    | undefined;

  if (!record) throw new Error('Download not found');
  if (record.Status === 'downloading') throw new Error('Download already in progress');

  db.prepare(
    'UPDATE Download SET Status = ?, DownloadedPages = 0, TotalPages = 0, ErrorMessage = NULL WHERE Id = ?',
  ).run('downloading', downloadId);

  processDownload(downloadId, record.Article).catch(() => {});
}

async function processDownload(downloadId: number, articleId: string): Promise<void> {
  const db = getUserDb();
  const tag = `[download][article=${articleId}][id=${downloadId}]`;

  try {
    console.log(`${tag} Resolving gallery...`);
    const gallery = await resolveGallery(Number(articleId));
    const urls = gallery.urls;
    console.log(`${tag} Found ${urls.length} pages`);

    db.prepare('UPDATE Download SET TotalPages = ? WHERE Id = ?').run(urls.length, downloadId);

    const articleDir = path.join(ARTICLES_DIR, articleId);
    fs.mkdirSync(articleDir, { recursive: true });

    const headers = await getGalleryHeaders(articleId);
    headers['User-Agent'] = USER_AGENT;

    for (let i = 0; i < urls.length; i++) {
      const url = urls[i];
      const ext = getExtFromUrl(url);
      const filePath = path.join(articleDir, `${i}${ext}`);

      const res = await fetchWithRetry(url, headers, tag, i);

      const buffer = Buffer.from(await res.arrayBuffer());
      fs.writeFileSync(filePath, buffer);

      db.prepare('UPDATE Download SET DownloadedPages = ? WHERE Id = ?').run(i + 1, downloadId);
    }

    console.log(`${tag} Completed (${urls.length} pages)`);
    db.prepare('UPDATE Download SET Status = ? WHERE Id = ?').run('completed', downloadId);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    const stack = err instanceof Error ? err.stack : undefined;
    console.error(`${tag} FAILED:`, message);
    if (stack) console.error(stack);
    db.prepare('UPDATE Download SET Status = ?, ErrorMessage = ? WHERE Id = ?').run(
      'failed',
      message,
      downloadId,
    );
  }
}
