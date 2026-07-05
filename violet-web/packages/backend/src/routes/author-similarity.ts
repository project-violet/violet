import { Router } from 'express';
import type { Article } from '@violet-web/shared';
import { getContentDb, isContentDbReady } from '../services/content-db.js';
import {
  type AuthorSharedKeyword,
  type AuthorSimilarityAuthor,
  type AuthorSimilarityNeighbor,
  findAuthorSimilarity,
} from '../services/author-similarity.js';

export const authorSimilarityRouter = Router();

interface AuthorSimilarityGroup {
  authorKey: string;
  authorName: string;
  workCount: number;
  matchedWorkCount?: number;
  keywordCount?: number;
  score?: number;
  sharedKeywordCount?: number;
  sharedKeywords?: AuthorSharedKeyword[];
  works: Article[];
}

function normalizeAuthor(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function normalizeLimit(value: unknown, fallback: number, max: number): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  return Math.max(1, Math.min(max, Math.trunc(parsed)));
}

function escapeLike(value: string): string {
  return value.replace(/[\\%_]/g, (match) => `\\${match}`);
}

export function normalizeContentLanguage(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const normalized = value.trim().toLowerCase();
  return ['korean', 'english', 'japanese', 'chinese'].includes(normalized) ? normalized : null;
}

function authorLookupNames(authorKey: string, authorName: string): string[] {
  return Array.from(new Set([
    authorName,
    authorName.replace(/_/g, ' '),
    authorKey,
    authorKey.replace(/ /g, '_'),
  ].map((value) => value.trim()).filter(Boolean)));
}

export function buildLatestAuthorWorksQuery(
  names: string[],
  limit: number,
  language: string | null,
): { sql: string; params: Array<string | number> } {
  const conditions = names.map(() => 'Artists LIKE ? ESCAPE \'\\\'').join(' OR ');
  const params: Array<string | number> = names.map((name) => `%|${escapeLike(name)}|%`);
  const languageCondition = language ? ' AND Language = ?' : '';
  if (language) {
    params.push(language);
  }
  params.push(limit);
  return {
    sql: `SELECT * FROM HitomiColumnModel
       WHERE ExistOnHitomi = 1 AND (${conditions})${languageCondition}
       ORDER BY Published DESC, Id DESC
       LIMIT ?`,
    params,
  };
}

function findLatestAuthorWorks(
  authorKey: string,
  authorName: string,
  limit: number,
  language: string | null,
): Article[] {
  const names = authorLookupNames(authorKey, authorName);
  if (names.length === 0) {
    return [];
  }
  const query = buildLatestAuthorWorksQuery(names, limit, language);
  const db = getContentDb();
  return db
    .prepare(query.sql)
    .all(...query.params) as Article[];
}

function targetGroup(
  author: AuthorSimilarityAuthor,
  worksLimit: number,
  language: string | null,
): AuthorSimilarityGroup {
  return {
    authorKey: author.authorKey,
    authorName: author.authorName,
    workCount: author.workCount,
    matchedWorkCount: author.matchedWorkCount,
    keywordCount: author.keywordCount,
    works: findLatestAuthorWorks(author.authorKey, author.authorName, worksLimit, language),
  };
}

function neighborGroup(
  author: AuthorSimilarityNeighbor,
  worksLimit: number,
  language: string | null,
): AuthorSimilarityGroup {
  return {
    authorKey: author.authorKey,
    authorName: author.authorName,
    workCount: author.workCount,
    score: author.score,
    sharedKeywordCount: author.sharedKeywordCount,
    sharedKeywords: author.sharedKeywords,
    works: findLatestAuthorWorks(author.authorKey, author.authorName, worksLimit, language),
  };
}

authorSimilarityRouter.get('/', async (req, res) => {
  if (!isContentDbReady()) {
    res.status(503).json({ error: 'Database syncing, please wait.' });
    return;
  }

  const author = normalizeAuthor(req.query.author);
  const limit = normalizeLimit(req.query.limit, 20, 50);
  const worksLimit = normalizeLimit(req.query.works, 5, 5);
  const language = normalizeContentLanguage(req.query.language);

  if (!author) {
    res.status(400).json({ error: 'Query parameter "author" is required.' });
    return;
  }

  try {
    const result = await findAuthorSimilarity(author, limit);
    if (!result) {
      res.status(404).json({ error: 'Author similarity not found.' });
      return;
    }

    res.json({
      generatedAt: result.generatedAt,
      params: result.params,
      target: targetGroup(result.target, worksLimit, language),
      similarAuthors: result.similarAuthors.map((item) => neighborGroup(item, worksLimit, language)),
    });
  } catch (error) {
    res.status(502).json({
      error: error instanceof Error ? error.message : 'Failed to load author similarity.',
    });
  }
});
