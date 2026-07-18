import { open, readFile, stat, type FileHandle } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import type { IntensityTimeline, IntensityTimelineStatus } from '@violet-web/shared';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const WORK_ID_PREFIX = Buffer.from('{"work_id":');

interface LineLocation {
  offset: number;
  length: number;
}

interface StoredTimeline {
  work_id: number;
  page_count: number;
  raw: number[];
  smooth: number[];
  peaks: Array<[number, number]>;
  interpolated_ranges?: Array<[number, number]>;
  status?: 'no_dialogue_chunks';
}

function defaultTimelinePath(): string {
  return process.env.INTENSITY_TIMELINES_PATH
    ? path.resolve(process.env.INTENSITY_TIMELINES_PATH)
    : path.resolve(__dirname, '../../data/intensity-timelines.jsonl');
}

function readWorkId(buffer: Buffer, offset: number, end: number): number | null {
  if (end - offset <= WORK_ID_PREFIX.length) return null;
  for (let index = 0; index < WORK_ID_PREFIX.length; index += 1) {
    if (buffer[offset + index] !== WORK_ID_PREFIX[index]) return null;
  }

  let cursor = offset + WORK_ID_PREFIX.length;
  let workId = 0;
  let digits = 0;
  while (cursor < end) {
    const byte = buffer[cursor];
    if (byte < 48 || byte > 57) break;
    workId = workId * 10 + byte - 48;
    digits += 1;
    cursor += 1;
  }
  return digits > 0 ? workId : null;
}

function normalizeTimeline(stored: StoredTimeline): IntensityTimeline {
  return {
    workId: stored.work_id,
    pageCount: stored.page_count,
    raw: stored.raw,
    smooth: stored.smooth,
    peaks: stored.peaks,
    ...(stored.interpolated_ranges
      ? { interpolatedRanges: stored.interpolated_ranges }
      : {}),
    ...(stored.status ? { status: stored.status } : {}),
  };
}

export class IntensityTimelineStore {
  private readonly filePath: string;
  private readonly locations = new Map<number, LineLocation>();
  private initializePromise: Promise<void> | null = null;
  private fileHandle: FileHandle | null = null;
  private fileSize = 0;
  private initializationError: Error | null = null;

  constructor(filePath = defaultTimelinePath()) {
    this.filePath = filePath;
  }

  initialize(): Promise<void> {
    if (!this.initializePromise) {
      this.initializePromise = this.buildIndex().catch((error: unknown) => {
        this.initializationError = error instanceof Error ? error : new Error(String(error));
        throw this.initializationError;
      });
    }
    return this.initializePromise;
  }

  private async buildIndex(): Promise<void> {
    const [buffer, fileStats] = await Promise.all([
      readFile(this.filePath),
      stat(this.filePath),
    ]);
    this.fileSize = fileStats.size;

    let lineStart = 0;
    while (lineStart < buffer.length) {
      const newline = buffer.indexOf(10, lineStart);
      const lineEnd = newline === -1 ? buffer.length : newline;
      const workId = readWorkId(buffer, lineStart, lineEnd);
      if (workId !== null) {
        this.locations.set(workId, {
          offset: lineStart,
          length: lineEnd - lineStart,
        });
      }
      if (newline === -1) break;
      lineStart = newline + 1;
    }

    this.fileHandle = await open(this.filePath, 'r');
  }

  async get(workId: number): Promise<IntensityTimeline | null> {
    await this.initialize();
    const location = this.locations.get(workId);
    if (!location || !this.fileHandle) return null;

    const line = Buffer.allocUnsafe(location.length);
    const { bytesRead } = await this.fileHandle.read(
      line,
      0,
      location.length,
      location.offset,
    );
    if (bytesRead !== location.length) {
      throw new Error(`Short read for intensity timeline ${workId}`);
    }
    const stored = JSON.parse(line.toString('utf8')) as StoredTimeline;
    if (stored.work_id !== workId) {
      throw new Error(`Intensity timeline index mismatch for work ${workId}`);
    }
    return normalizeTimeline(stored);
  }

  async status(): Promise<IntensityTimelineStatus> {
    try {
      await this.initialize();
      return {
        available: true,
        indexedWorks: this.locations.size,
        fileSize: this.fileSize,
      };
    } catch (error) {
      return {
        available: false,
        indexedWorks: 0,
        fileSize: 0,
        error: this.initializationError?.message
          ?? (error instanceof Error ? error.message : String(error)),
      };
    }
  }

  async close(): Promise<void> {
    await this.fileHandle?.close();
    this.fileHandle = null;
  }
}

let timelineStore: IntensityTimelineStore | null = null;

export function getIntensityTimelineStore(): IntensityTimelineStore {
  if (!timelineStore) timelineStore = new IntensityTimelineStore();
  return timelineStore;
}
