import type { Article } from '@violet-web/shared';
import type { ContentLanguage } from '../stores/app-store';
import { api } from './client';

export interface AuthorSharedKeyword {
  keyword: string;
  score: number;
}

export interface AuthorSimilarityGroup {
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

export interface AuthorSimilarityResponse {
  generatedAt: string | null;
  params: Record<string, unknown>;
  target: AuthorSimilarityGroup;
  similarAuthors: AuthorSimilarityGroup[];
}

export async function fetchAuthorSimilarity(
  author: string,
  limit = 20,
  contentLanguage: ContentLanguage = 'all',
): Promise<AuthorSimilarityResponse> {
  const { data } = await api.get<AuthorSimilarityResponse>('/author-similarity', {
    params: { author, limit, works: 5, language: contentLanguage },
    timeout: 120000,
  });

  return {
    ...data,
    target: normalizeGroup(data.target),
    similarAuthors: Array.isArray(data.similarAuthors)
      ? data.similarAuthors.map(normalizeGroup)
      : [],
  };
}

function normalizeGroup(group: AuthorSimilarityGroup): AuthorSimilarityGroup {
  return {
    ...group,
    works: Array.isArray(group?.works) ? group.works : [],
    sharedKeywords: Array.isArray(group?.sharedKeywords) ? group.sharedKeywords : [],
  };
}
