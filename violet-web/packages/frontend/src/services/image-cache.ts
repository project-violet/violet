const DB_NAME = 'violet-image-cache';
const DB_VERSION = 2;
const STORE_NAME = 'images';
const THUMB_STORE = 'crop-thumbnails';

interface CachedImage {
  articleId: number;
  page: number;
  blob: Blob;
  contentType: string;
  size: number;
  lastAccessed: number;
  createdAt: number;
}

interface CropThumbnail {
  key: string; // "articleId:page:area"
  blob: Blob;
  createdAt: number;
}

let dbInstance: IDBDatabase | null = null;
let evictTimer: ReturnType<typeof setTimeout> | null = null;
let pendingMaxSize = 0;

function openDB(): Promise<IDBDatabase> {
  if (dbInstance) return Promise.resolve(dbInstance);

  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);

    request.onupgradeneeded = (event) => {
      const db = request.result;
      if ((event.oldVersion as number) < 1) {
        const store = db.createObjectStore(STORE_NAME, { keyPath: ['articleId', 'page'] });
        store.createIndex('lastAccessed', 'lastAccessed', { unique: false });
        store.createIndex('articleId', 'articleId', { unique: false });
      }
      if ((event.oldVersion as number) < 2) {
        db.createObjectStore(THUMB_STORE, { keyPath: 'key' });
      }
    };

    request.onsuccess = () => {
      dbInstance = request.result;
      dbInstance.onclose = () => { dbInstance = null; };
      resolve(dbInstance);
    };

    request.onerror = () => reject(request.error);
  });
}

export async function getCachedImage(
  articleId: number,
  page: number,
): Promise<{ blob: Blob; contentType: string } | null> {
  try {
    const db = await openDB();
    return new Promise((resolve) => {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      const store = tx.objectStore(STORE_NAME);
      const request = store.get([articleId, page]);

      request.onsuccess = () => {
        const result = request.result as CachedImage | undefined;
        if (result) {
          const now = Date.now();
          if (now - result.lastAccessed > 24 * 60 * 60 * 1000) {
            result.lastAccessed = now;
            store.put(result);
          }
          resolve({ blob: result.blob, contentType: result.contentType });
        } else {
          resolve(null);
        }
      };

      request.onerror = () => resolve(null);
    });
  } catch {
    return null;
  }
}

/**
 * Bulk read from the full images store in a single transaction.
 */
export async function getCachedImagesBulk(
  keys: Array<{ articleId: number; page: number }>,
): Promise<Map<string, { blob: Blob; contentType: string }>> {
  const results = new Map<string, { blob: Blob; contentType: string }>();
  if (keys.length === 0) return results;

  try {
    const db = await openDB();
    return new Promise((resolve) => {
      const tx = db.transaction(STORE_NAME, 'readonly');
      const store = tx.objectStore(STORE_NAME);
      let completed = 0;

      for (const key of keys) {
        const request = store.get([key.articleId, key.page]);
        request.onsuccess = () => {
          const result = request.result as CachedImage | undefined;
          if (result) {
            results.set(`${key.articleId}:${key.page}`, {
              blob: result.blob,
              contentType: result.contentType,
            });
          }
          if (++completed === keys.length) resolve(results);
        };
        request.onerror = () => {
          if (++completed === keys.length) resolve(results);
        };
      }
    });
  } catch {
    return results;
  }
}

/**
 * Bulk read crop thumbnails in a single transaction.
 */
export async function getCropThumbnailsBulk(
  keys: string[],
): Promise<Map<string, Blob>> {
  const results = new Map<string, Blob>();
  if (keys.length === 0) return results;

  try {
    const db = await openDB();
    return new Promise((resolve) => {
      const tx = db.transaction(THUMB_STORE, 'readonly');
      const store = tx.objectStore(THUMB_STORE);
      let completed = 0;

      for (const key of keys) {
        const request = store.get(key);
        request.onsuccess = () => {
          const result = request.result as CropThumbnail | undefined;
          if (result) {
            results.set(key, result.blob);
          }
          if (++completed === keys.length) resolve(results);
        };
        request.onerror = () => {
          if (++completed === keys.length) resolve(results);
        };
      }
    });
  } catch {
    return results;
  }
}

/**
 * Save a crop thumbnail for fast subsequent loads.
 */
export async function putCropThumbnail(
  key: string,
  blob: Blob,
): Promise<void> {
  try {
    const db = await openDB();
    const entry: CropThumbnail = { key, blob, createdAt: Date.now() };
    await new Promise<void>((resolve) => {
      const tx = db.transaction(THUMB_STORE, 'readwrite');
      const store = tx.objectStore(THUMB_STORE);
      const request = store.put(entry);
      request.onsuccess = () => resolve();
      request.onerror = () => resolve();
    });
  } catch {
    // best-effort
  }
}

export async function putCachedImage(
  articleId: number,
  page: number,
  blob: Blob,
  contentType: string,
  maxSizeBytes: number,
): Promise<void> {
  try {
    const db = await openDB();
    const now = Date.now();
    const entry: CachedImage = {
      articleId,
      page,
      blob,
      contentType,
      size: blob.size,
      lastAccessed: now,
      createdAt: now,
    };

    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      const store = tx.objectStore(STORE_NAME);
      const request = store.put(entry);
      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error);
    });

    scheduleEviction(maxSizeBytes);
  } catch {
    // best-effort
  }
}

export async function getCacheStats(): Promise<{ totalSizeBytes: number; itemCount: number }> {
  try {
    const db = await openDB();
    return new Promise((resolve) => {
      const tx = db.transaction(STORE_NAME, 'readonly');
      const store = tx.objectStore(STORE_NAME);
      const request = store.getAll();

      request.onsuccess = () => {
        const items = request.result as CachedImage[];
        const totalSizeBytes = items.reduce((sum, item) => sum + item.size, 0);
        resolve({ totalSizeBytes, itemCount: items.length });
      };

      request.onerror = () => resolve({ totalSizeBytes: 0, itemCount: 0 });
    });
  } catch {
    return { totalSizeBytes: 0, itemCount: 0 };
  }
}

export async function cleanupExpired(days: number): Promise<void> {
  try {
    const db = await openDB();
    const cutoff = Date.now() - days * 24 * 60 * 60 * 1000;

    const items = await new Promise<CachedImage[]>((resolve) => {
      const tx = db.transaction(STORE_NAME, 'readonly');
      const store = tx.objectStore(STORE_NAME);
      const index = store.index('lastAccessed');
      const range = IDBKeyRange.upperBound(cutoff);
      const request = index.getAll(range);

      request.onsuccess = () => resolve(request.result as CachedImage[]);
      request.onerror = () => resolve([]);
    });

    if (items.length === 0) return;

    const tx = db.transaction(STORE_NAME, 'readwrite');
    const store = tx.objectStore(STORE_NAME);
    for (const item of items) {
      store.delete([item.articleId, item.page]);
    }
  } catch {
    // best-effort
  }
}

export async function clearAllCache(): Promise<void> {
  try {
    const db = await openDB();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction([STORE_NAME, THUMB_STORE], 'readwrite');
      const imgStore = tx.objectStore(STORE_NAME);
      const thumbStore = tx.objectStore(THUMB_STORE);
      imgStore.clear();
      thumbStore.clear();
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  } catch {
    // best-effort
  }
}

function scheduleEviction(maxSizeBytes: number) {
  pendingMaxSize = maxSizeBytes;
  if (evictTimer) clearTimeout(evictTimer);
  evictTimer = setTimeout(() => {
    evictTimer = null;
    evictIfNeeded(pendingMaxSize).catch(() => {});
  }, 2000);
}

async function evictIfNeeded(maxSizeBytes: number): Promise<void> {
  try {
    const db = await openDB();
    const items = await new Promise<CachedImage[]>((resolve) => {
      const tx = db.transaction(STORE_NAME, 'readonly');
      const store = tx.objectStore(STORE_NAME);
      const request = store.getAll();

      request.onsuccess = () => resolve(request.result as CachedImage[]);
      request.onerror = () => resolve([]);
    });

    let totalSize = items.reduce((sum, item) => sum + item.size, 0);
    if (totalSize <= maxSizeBytes) return;

    // Sort by lastAccessed ascending (oldest first) for LRU eviction
    items.sort((a, b) => a.lastAccessed - b.lastAccessed);

    const tx = db.transaction(STORE_NAME, 'readwrite');
    const store = tx.objectStore(STORE_NAME);

    for (const item of items) {
      if (totalSize <= maxSizeBytes) break;
      store.delete([item.articleId, item.page]);
      totalSize -= item.size;
    }
  } catch {
    // best-effort
  }
}
