import { access, readFile, stat } from 'fs/promises';
import path from 'path';

export interface AuthorSharedKeyword {
  keyword: string;
  score: number;
}

export interface AuthorSimilarityAuthor {
  authorKey: string;
  authorName: string;
  workCount: number;
  matchedWorkCount: number;
  keywordCount: number;
}

export interface AuthorSimilarityNeighbor {
  authorKey: string;
  authorName: string;
  workCount: number;
  score: number;
  sharedKeywordCount: number;
  sharedKeywords: AuthorSharedKeyword[];
}

export interface AuthorSimilarityLookupResult {
  generatedAt: string | null;
  params: Record<string, unknown>;
  target: AuthorSimilarityAuthor;
  similarAuthors: AuthorSimilarityNeighbor[];
}

interface RawAuthorSimilarityJSON {
  generated_at?: unknown;
  params?: unknown;
  authors?: unknown;
}

interface RawAuthor {
  author_key?: unknown;
  author_name?: unknown;
  work_count?: unknown;
  matched_work_count?: unknown;
  keyword_count?: unknown;
  similar_authors?: unknown;
}

interface RawNeighbor {
  author_key?: unknown;
  author_name?: unknown;
  work_count?: unknown;
  score?: unknown;
  shared_keyword_count?: unknown;
  shared_keywords?: unknown;
}

interface AuthorSimilarityCache {
  path: string;
  mtimeMs: number;
  data: AuthorSimilarityData;
}

interface AuthorSimilarityData {
  generatedAt: string | null;
  params: Record<string, unknown>;
  authorsByKey: Map<string, AuthorSimilarityAuthor & { similarAuthors: AuthorSimilarityNeighbor[] }>;
}

let cache: AuthorSimilarityCache | null = null;

export function normalizeAuthorSimilarityKey(value: string): string {
  return value.replace(/_/g, ' ').trim().toLowerCase().split(/\s+/).filter(Boolean).join(' ');
}

export async function resolveAuthorSimilarityPath(): Promise<string | null> {
  const configured = process.env.AUTHOR_SIMILARITY_PATH?.trim();
  const candidates = [
    configured,
    path.resolve(process.cwd(), '..', '..', '..', 'violet-graph', 'author_similarity.json'),
    path.resolve(process.cwd(), '..', '..', 'violet-graph', 'author_similarity.json'),
    path.resolve(process.cwd(), '..', 'violet-graph', 'author_similarity.json'),
    path.resolve(process.cwd(), 'violet-graph', 'author_similarity.json'),
  ].filter((candidate): candidate is string => Boolean(candidate));

  for (const candidate of candidates) {
    try {
      await access(candidate);
      return candidate;
    } catch {
      // Try the next conventional workspace location.
    }
  }
  return null;
}

export async function findAuthorSimilarity(
  author: string,
  limit: number,
): Promise<AuthorSimilarityLookupResult | null> {
  const filePath = await resolveAuthorSimilarityPath();
  if (!filePath) {
    throw new Error('author_similarity.json not found. Generate it with violet-graph author-similarity first.');
  }
  return findAuthorSimilarityFromFile(filePath, author, limit);
}

export async function findAuthorSimilarityFromFile(
  filePath: string,
  author: string,
  limit: number,
): Promise<AuthorSimilarityLookupResult | null> {
  const data = await loadAuthorSimilarityData(filePath);
  const key = normalizeAuthorSimilarityKey(author);
  const target = data.authorsByKey.get(key);
  if (!target) {
    return null;
  }

  const normalizedLimit = Math.max(1, Math.min(100, Math.trunc(limit) || 20));
  const { similarAuthors, ...targetBase } = target;
  return {
    generatedAt: data.generatedAt,
    params: data.params,
    target: targetBase,
    similarAuthors: similarAuthors.slice(0, normalizedLimit),
  };
}

async function loadAuthorSimilarityData(filePath: string): Promise<AuthorSimilarityData> {
  const info = await stat(filePath);
  if (cache && cache.path === filePath && cache.mtimeMs === info.mtimeMs) {
    return cache.data;
  }

  const raw = JSON.parse(await readFile(filePath, 'utf8')) as RawAuthorSimilarityJSON;
  const data = normalizeAuthorSimilarityData(raw);
  cache = { path: filePath, mtimeMs: info.mtimeMs, data };
  return data;
}

function normalizeAuthorSimilarityData(raw: RawAuthorSimilarityJSON): AuthorSimilarityData {
  const authorsByKey = new Map<string, AuthorSimilarityAuthor & { similarAuthors: AuthorSimilarityNeighbor[] }>();
  const rawAuthors = Array.isArray(raw.authors) ? raw.authors : [];
  for (const rawAuthor of rawAuthors) {
    const author = normalizeRawAuthor(rawAuthor as RawAuthor);
    if (!author) {
      continue;
    }
    authorsByKey.set(author.authorKey, author);
  }
  return {
    generatedAt: typeof raw.generated_at === 'string' ? raw.generated_at : null,
    params: isRecord(raw.params) ? raw.params : {},
    authorsByKey,
  };
}

function normalizeRawAuthor(
  raw: RawAuthor,
): (AuthorSimilarityAuthor & { similarAuthors: AuthorSimilarityNeighbor[] }) | null {
  const authorKey = typeof raw.author_key === 'string' ? normalizeAuthorSimilarityKey(raw.author_key) : '';
  if (!authorKey) {
    return null;
  }
  return {
    authorKey,
    authorName: typeof raw.author_name === 'string' ? raw.author_name : authorKey,
    workCount: toInt(raw.work_count),
    matchedWorkCount: toInt(raw.matched_work_count),
    keywordCount: toInt(raw.keyword_count),
    similarAuthors: normalizeRawNeighbors(raw.similar_authors),
  };
}

function normalizeRawNeighbors(raw: unknown): AuthorSimilarityNeighbor[] {
  if (!Array.isArray(raw)) {
    return [];
  }
  return raw
    .map((item) => normalizeRawNeighbor(item as RawNeighbor))
    .filter((item): item is AuthorSimilarityNeighbor => item !== null);
}

function normalizeRawNeighbor(raw: RawNeighbor): AuthorSimilarityNeighbor | null {
  const authorKey = typeof raw.author_key === 'string' ? normalizeAuthorSimilarityKey(raw.author_key) : '';
  if (!authorKey) {
    return null;
  }
  return {
    authorKey,
    authorName: typeof raw.author_name === 'string' ? raw.author_name : authorKey,
    workCount: toInt(raw.work_count),
    score: toNumber(raw.score),
    sharedKeywordCount: toInt(raw.shared_keyword_count),
    sharedKeywords: normalizeSharedKeywords(raw.shared_keywords),
  };
}

function normalizeSharedKeywords(raw: unknown): AuthorSharedKeyword[] {
  if (!Array.isArray(raw)) {
    return [];
  }
  return raw
    .map((item) => {
      if (!isRecord(item) || typeof item.keyword !== 'string') {
        return null;
      }
      return {
        keyword: item.keyword,
        score: toNumber(item.score),
      };
    })
    .filter((item): item is AuthorSharedKeyword => item !== null);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function toInt(value: unknown): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.trunc(parsed) : 0;
}

function toNumber(value: unknown): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}
