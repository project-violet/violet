import { createApp } from './app.js';
import { SyncManager } from './services/sync-manager.js';
import { recoverInterruptedDownloads } from './services/download-service.js';
import { isContentDbReady, getContentDb, getDbPath, closeContentDb, reopenContentDb, isFtsReady, resetFtsReady } from './services/content-db.js';
import { buildFtsIndex } from './services/fts-indexer.js';
import Database from 'better-sqlite3';
import { getIntensityTimelineStore } from './services/intensity-timelines.js';

const PORT = process.env.PORT ? parseInt(process.env.PORT) : 3001;

const app = createApp();

app.listen(PORT, async () => {
  console.log(`[violet-web] Backend running on http://localhost:${PORT}`);

  getIntensityTimelineStore().status().then((status) => {
    if (status.available) {
      console.log(`[violet-web] Intensity timelines indexed: ${status.indexedWorks}`);
    } else {
      console.warn(`[violet-web] Intensity timelines unavailable: ${status.error}`);
    }
  });

  // Recover downloads interrupted by previous shutdown
  recoverInterruptedDownloads();

  // Build FTS search indexes in background if needed
  if (isContentDbReady()) {
    try {
      getContentDb(); // ensure DB is open for isFtsReady check
      if (!isFtsReady()) {
        console.log('[violet-web] FTS index not found, building in background...');
        // Build asynchronously so server can serve requests (LIKE fallback) during build
        setImmediate(() => {
          try {
            closeContentDb();
            const writeDb = new Database(getDbPath(), { readonly: false });
            writeDb.pragma('journal_mode = WAL');
            buildFtsIndex(writeDb);
            writeDb.close();
            reopenContentDb();
            resetFtsReady();
            console.log('[violet-web] FTS index ready');
          } catch (err) {
            console.error('[violet-web] FTS build failed:', err);
            // Reopen readonly connection so LIKE queries still work
            try { reopenContentDb(); } catch { /* ignore */ }
          }
        });
      } else {
        console.log('[violet-web] FTS index already available');
      }
    } catch (err) {
      console.error('[violet-web] FTS check failed:', err);
    }
  }

  // Initialize sync manager
  try {
    const syncManager = SyncManager.getInstance();
    await syncManager.initialize();
  } catch (error) {
    console.error('[violet-web] Failed to initialize SyncManager:', error);
  }
});
