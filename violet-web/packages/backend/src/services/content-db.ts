import Database from 'better-sqlite3';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

let db: Database.Database | null = null;
let ftsReady: boolean | null = null;

export function getDbPath(): string {
  return process.env.DATA_DB_PATH || path.resolve(__dirname, '../../data/data.db');
}

export function isContentDbReady(): boolean {
  return fs.existsSync(getDbPath());
}

export function getContentDb(): Database.Database {
  if (db) return db;

  const dbPath = getDbPath();
  db = new Database(dbPath, { readonly: true });
  // Performance: memory-mapped I/O and larger page cache
  db.pragma('mmap_size = 1073741824');
  db.pragma('cache_size = -20000');
  return db;
}

export function closeContentDb(): void {
  if (db) {
    db.close();
    db = null;
  }
}

export function reopenContentDb(): Database.Database {
  closeContentDb();
  ftsReady = null;
  return getContentDb();
}

/** Check if FTS5 search indexes exist. Result is cached. */
export function isFtsReady(): boolean {
  if (ftsReady !== null) return ftsReady;
  if (!db) return false;
  try {
    const row = db.prepare(
      "SELECT count(*) as cnt FROM sqlite_master WHERE type='table' AND name IN ('FtsTitle', 'FtsTags')",
    ).get() as { cnt: number };
    ftsReady = row.cnt === 2;
    return ftsReady;
  } catch {
    ftsReady = false;
    return false;
  }
}

/** Reset FTS readiness cache (call after building/rebuilding FTS). */
export function resetFtsReady(): void {
  ftsReady = null;
}
