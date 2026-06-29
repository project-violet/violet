import fs from 'fs';
import path from 'path';
import Database from 'better-sqlite3';
import { fileURLToPath } from 'url';
import { getDbPath, getContentDb, closeContentDb, reopenContentDb } from './content-db.js';
import { buildSuggestionCache } from './suggestion-engine.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

interface SyncInfoRecord {
  type: 'db' | 'chunk';
  timestamp: number;
  url: string;
  size: number;
}

interface SyncState {
  syncLatest: number;
  databaseSync: string | null;
  databaseType: string;
  lastSyncAt: string | null;
}

export type SyncStatus =
  | 'idle'
  | 'checking'
  | 'downloading_full'
  | 'applying_chunks'
  | 'building_cache'
  | 'error';

export interface SyncProgress {
  status: SyncStatus;
  lastSync: string | null;
  lastSyncDb: string | null;
  dbExists: boolean;
  error: string | null;
  progress?: {
    current: number;
    total: number;
    message: string;
  };
}

export class SyncManager {
  private static instance: SyncManager;
  private syncInterval: NodeJS.Timeout | null = null;
  private isSyncing = false;
  private currentStatus: SyncStatus = 'idle';
  private currentError: string | null = null;
  private currentProgress?: { current: number; total: number; message: string };
  private statePath: string;
  private dataDir: string;

  private constructor() {
    this.dataDir = path.resolve(__dirname, '../../data');
    this.statePath = path.join(this.dataDir, 'sync-state.json');
  }

  static getInstance(): SyncManager {
    if (!SyncManager.instance) {
      SyncManager.instance = new SyncManager();
    }
    return SyncManager.instance;
  }

  async initialize(): Promise<void> {
    console.log('[SyncManager] Initializing...');

    // Ensure data directory exists
    if (!fs.existsSync(this.dataDir)) {
      fs.mkdirSync(this.dataDir, { recursive: true });
    }

    // Check if DB exists
    const dbExists = fs.existsSync(getDbPath());

    if (!dbExists) {
      console.log('[SyncManager] No database found, downloading full DB...');
      // Start download in background so the server can start serving requests
      // (frontend will poll status and show overlay)
      this.downloadFullDB().catch((err) => {
        console.error('[SyncManager] Full DB download error:', err);
      });
    } else {
      console.log('[SyncManager] Database exists, checking for updates...');
      await this.checkAndSync();
    }

    // Start periodic sync (default: 30 minutes)
    const intervalMs = process.env.SYNC_INTERVAL_MS
      ? parseInt(process.env.SYNC_INTERVAL_MS)
      : 30 * 60 * 1000;

    if (process.env.SYNC_ENABLED !== 'false') {
      this.syncInterval = setInterval(() => {
        this.checkAndSync().catch((err) => {
          console.error('[SyncManager] Periodic sync error:', err);
        });
      }, intervalMs);

      console.log(
        `[SyncManager] Periodic sync started (interval: ${intervalMs}ms)`,
      );
    }
  }

  async checkAndSync(): Promise<void> {
    if (this.isSyncing) {
      console.log('[SyncManager] Sync already in progress, skipping');
      return;
    }

    try {
      this.isSyncing = true;
      this.currentStatus = 'checking';
      this.currentError = null;

      const state = this.loadState();
      const records = await this.parseSyncVersion();

      // Check if full DB re-download is needed (>7 days since last full sync)
      if (state.databaseSync) {
        const lastSyncDate = new Date(state.databaseSync);
        const daysSinceSync =
          (Date.now() - lastSyncDate.getTime()) / (1000 * 60 * 60 * 24);

        if (daysSinceSync > 7) {
          console.log(
            `[SyncManager] Last full sync was ${daysSinceSync.toFixed(1)} days ago, re-downloading full DB`,
          );
          await this.downloadFullDB();
          return;
        }
      }

      // Filter chunks newer than syncLatest
      const newChunks = records.filter(
        (r) => r.type === 'chunk' && r.timestamp > state.syncLatest,
      );

      if (newChunks.length === 0) {
        console.log('[SyncManager] No new chunks to sync');
        this.currentStatus = 'idle';
        return;
      }

      // Check if total chunk size exceeds threshold (10MB)
      const totalSize = newChunks.reduce((sum, r) => sum + r.size, 0);
      const threshold = 10 * 1024 * 1024; // 10MB

      if (totalSize > threshold) {
        console.log(
          `[SyncManager] Chunk size (${(totalSize / 1024 / 1024).toFixed(1)}MB) exceeds threshold, re-downloading full DB`,
        );
        await this.downloadFullDB();
        return;
      }

      // Sync chunks
      await this.syncChunks(newChunks);
    } catch (error) {
      this.currentStatus = 'error';
      this.currentError = error instanceof Error ? error.message : String(error);
      console.error('[SyncManager] Sync error:', error);
      throw error;
    } finally {
      this.isSyncing = false;
      if (this.currentStatus !== 'error') {
        this.currentStatus = 'idle';
      }
    }
  }

  async triggerFullSync(): Promise<void> {
    if (this.isSyncing) {
      throw new Error('Sync already in progress');
    }
    await this.downloadFullDB();
  }

  getStatus(): SyncProgress {
    const state = this.loadState();
    return {
      status: this.currentStatus,
      lastSync: state.lastSyncAt || null,
      lastSyncDb: state.databaseSync,
      dbExists: fs.existsSync(getDbPath()),
      error: this.currentError,
      progress: this.currentProgress,
    };
  }

  private async parseSyncVersion(): Promise<SyncInfoRecord[]> {
    const branch = 'master';
    const url = `https://raw.githubusercontent.com/violet-dev/sync-data/${branch}/syncversion.txt`;

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to fetch syncversion.txt: ${response.statusText}`);
    }

    const text = await response.text();
    const lines = text.split('\n').filter((line) => line && !line.startsWith('#'));

    // Parse lines in reverse order (latest first)
    const records: SyncInfoRecord[] = [];
    for (let i = lines.length - 1; i >= 0; i--) {
      const parts = lines[i].trim().split(' ');
      if (parts.length < 3) continue;

      const type = parts[0] as 'db' | 'chunk';
      const timestamp = parseInt(parts[1]);
      const url = parts[2];
      const size = type === 'chunk' && parts.length > 3 ? parseInt(parts[3]) : 0;

      // Only include JSON chunks
      if (type === 'chunk' && !url.endsWith('.json')) continue;

      records.push({ type, timestamp, url, size });
    }

    return records;
  }

  private async downloadFullDB(): Promise<void> {
    try {
      this.isSyncing = true;
      this.currentStatus = 'downloading_full';
      this.currentError = null;

      console.log('[SyncManager] Starting full DB download...');

      const records = await this.parseSyncVersion();
      const dbRecord = records.find((r) => r.type === 'db');

      if (!dbRecord) {
        throw new Error('No database record found in syncversion.txt');
      }

      const language = process.env.SYNC_LANGUAGE || 'global';
      const dbUrl = dbRecord.url + this.getDbPostfix(language);

      console.log(`[SyncManager] Downloading from: ${dbUrl}`);

      // Download DB with streaming progress
      const response = await fetch(dbUrl);
      if (!response.ok) {
        throw new Error(`Failed to download DB: ${response.statusText}`);
      }

      const contentLength = parseInt(response.headers.get('content-length') || '0', 10);
      const totalMB = contentLength > 0 ? (contentLength / 1024 / 1024).toFixed(1) : '?';

      this.currentProgress = { current: 0, total: contentLength || 100, message: `Downloading database (0/${totalMB} MB)` };

      const dbPath = getDbPath();
      const tempPath = dbPath + '.tmp';

      if (!response.body) {
        // Fallback: no streaming support
        const buffer = await response.arrayBuffer();
        fs.writeFileSync(tempPath, Buffer.from(buffer));
      } else {
        // Stream to file with progress updates
        const fileStream = fs.createWriteStream(tempPath);
        const reader = response.body.getReader();
        let received = 0;

        while (true) {
          const { done, value } = await reader.read();
          if (done) break;

          fileStream.write(Buffer.from(value));
          received += value.byteLength;

          const receivedMB = (received / 1024 / 1024).toFixed(1);
          this.currentProgress = {
            current: received,
            total: contentLength || received,
            message: `Downloading database (${receivedMB}/${totalMB} MB)`,
          };
        }

        await new Promise<void>((resolve, reject) => {
          fileStream.end(() => resolve());
          fileStream.on('error', reject);
        });

        console.log(`[SyncManager] Downloaded ${(received / 1024 / 1024).toFixed(1)}MB`);
      }

      this.currentProgress = { current: contentLength || 100, total: contentLength || 100, message: 'Saving database' };

      // Close existing DB connection
      closeContentDb();

      // Replace old DB with new one
      if (fs.existsSync(dbPath)) {
        fs.unlinkSync(dbPath);
      }
      fs.renameSync(tempPath, dbPath);

      // Reopen DB
      reopenContentDb();

      this.currentProgress = { current: 100, total: 100, message: 'Complete' };

      // Update state
      const now = new Date().toISOString();
      const state: SyncState = {
        syncLatest: dbRecord.timestamp,
        databaseSync: now,
        databaseType: language,
        lastSyncAt: now,
      };
      this.saveState(state);

      console.log('[SyncManager] Full DB download complete');

      // Build suggestion cache after fresh download
      this.currentStatus = 'building_cache';
      this.currentProgress = undefined;
      console.log('[SyncManager] Building suggestion cache...');
      try {
        buildSuggestionCache(getContentDb());
        console.log('[SyncManager] Suggestion cache built');
      } catch (cacheErr) {
        console.error('[SyncManager] Failed to build suggestion cache:', cacheErr);
      }

      this.currentStatus = 'idle';
    } catch (error) {
      this.currentStatus = 'error';
      this.currentError = error instanceof Error ? error.message : String(error);
      throw error;
    } finally {
      this.isSyncing = false;
      this.currentProgress = undefined;
    }
  }

  private async syncChunks(chunks: SyncInfoRecord[]): Promise<void> {
    try {
      this.currentStatus = 'applying_chunks';
      console.log(`[SyncManager] Syncing ${chunks.length} chunks...`);

      // Download chunks in batches of 16
      const batchSize = 16;
      const allResponses: string[] = [];

      for (let i = 0; i < chunks.length; i += batchSize) {
        const batch = chunks.slice(i, Math.min(i + batchSize, chunks.length));

        this.currentProgress = {
          current: i,
          total: chunks.length,
          message: `Downloading chunks ${i + 1}-${Math.min(i + batchSize, chunks.length)}/${chunks.length}`,
        };

        const responses = await Promise.all(
          batch.map(async (chunk) => {
            const res = await fetch(chunk.url);
            if (!res.ok) {
              throw new Error(`Failed to download chunk: ${res.statusText}`);
            }
            return res.text();
          }),
        );

        allResponses.push(...responses);
      }

      // Apply chunks to database (oldest first)
      this.currentProgress = {
        current: 0,
        total: chunks.length,
        message: 'Applying chunks to database',
      };

      // Close readonly connection before writing
      closeContentDb();

      // Create a writable DB connection
      const dbPath = getDbPath();
      const writeDb = new Database(dbPath, { readonly: false });
      writeDb.pragma('journal_mode = WAL');

      try {
        // Process chunks in reverse order (oldest first)
        for (let i = chunks.length - 1; i >= 0; i--) {
          const chunk = chunks[i];
          const jsonData = JSON.parse(allResponses[i]);

          this.currentProgress = {
            current: chunks.length - i,
            total: chunks.length,
            message: `Applying chunk ${chunks.length - i}/${chunks.length}`,
          };

          // Filter by language if needed
          const language = this.translateToLanguage(process.env.SYNC_LANGUAGE || 'global');
          const records = Array.isArray(jsonData) ? jsonData : [jsonData];

          const filteredRecords = language
            ? records.filter((r) => {
                const lang = r.Language || 'n/a';
                return lang === language || lang === 'n/a';
              })
            : records;

          // Batch insert
          const insertStmt = writeDb.prepare(`
            INSERT OR REPLACE INTO HitomiColumnModel
            (Id, Title, Artists, Groups, Type, Language, Series, Characters, Tags, Files, Thumbnail, EHash, Published, ExistOnHitomi, Class, Uploader)
            VALUES (@Id, @Title, @Artists, @Groups, @Type, @Language, @Series, @Characters, @Tags, @Files, @Thumbnail, @EHash, @Published, @ExistOnHitomi, @Class, @Uploader)
          `);

          const transaction = writeDb.transaction((records) => {
            for (const record of records) {
              insertStmt.run(record);
            }
          });

          transaction(filteredRecords);

          // Update syncLatest
          const state = this.loadState();
          state.syncLatest = chunk.timestamp;
          this.saveState(state);
        }
      } finally {
        writeDb.close();
        // Reopen readonly connection for queries
        reopenContentDb();
      }

      // Update lastSyncAt
      const state = this.loadState();
      state.lastSyncAt = new Date().toISOString();
      this.saveState(state);

      console.log(`[SyncManager] Successfully synced ${chunks.length} chunks`);
      this.currentStatus = 'idle';
    } catch (error) {
      this.currentStatus = 'error';
      this.currentError = error instanceof Error ? error.message : String(error);
      throw error;
    } finally {
      this.currentProgress = undefined;
    }
  }

  private getDbPostfix(language: string): string {
    const postfixes: Record<string, string> = {
      global: '.db',
      ko: '-korean.db',
      en: '-english.db',
      ja: '-japanese.db',
      zh: '-chinese.db',
    };
    return postfixes[language] || '.db';
  }

  private translateToLanguage(lang: string): string {
    const translations: Record<string, string> = {
      global: '',
      ko: 'korean',
      en: 'english',
      ja: 'japanese',
      zh: 'chinese',
    };
    return translations[lang] || '';
  }

  private loadState(): SyncState {
    if (!fs.existsSync(this.statePath)) {
      return {
        syncLatest: 0,
        databaseSync: null,
        databaseType: process.env.SYNC_LANGUAGE || 'global',
        lastSyncAt: null,
      };
    }

    try {
      const data = fs.readFileSync(this.statePath, 'utf-8');
      return JSON.parse(data);
    } catch {
      return {
        syncLatest: 0,
        databaseSync: null,
        databaseType: process.env.SYNC_LANGUAGE || 'global',
        lastSyncAt: null,
      };
    }
  }

  private saveState(state: SyncState): void {
    fs.writeFileSync(this.statePath, JSON.stringify(state, null, 2), 'utf-8');
  }

  stop(): void {
    if (this.syncInterval) {
      clearInterval(this.syncInterval);
      this.syncInterval = null;
      console.log('[SyncManager] Periodic sync stopped');
    }
  }
}
