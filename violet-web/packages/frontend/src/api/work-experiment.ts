import type { MessageSearchResponse } from '@violet-web/shared';
import type { RelatedWork } from '../types/keyword-graph';
import { api } from './client';
import { messageSearch } from './message-search';

export type WorkExperimentMode = 'work' | 'author';

export interface WorkExperimentRequest {
  workId: string;
  messageQuery: string;
  keywordGraphServerUrl: string;
  messageSearchServerUrl: string;
  limit: number;
}

export interface WorkExperimentResponse {
  scope: WorkExperimentMode;
  author?: string;
  articleIds: string[];
  work: RelatedWork;
  messages: MessageSearchResponse | null;
}

export interface AuthorExperimentRequest {
  author: string;
  messageQuery: string;
  keywordGraphServerUrl: string;
  messageSearchServerUrl: string;
  limit: number;
}

export async function fetchWorkExperiment(
  request: WorkExperimentRequest,
): Promise<WorkExperimentResponse> {
  const workId = request.workId.trim();
  const messageQuery = request.messageQuery.trim();
  const work = await fetchWorkKeywords(request.keywordGraphServerUrl, workId);
  const messages = messageQuery
    ? await messageSearch(
        messageQuery,
        'contains',
        request.limit,
        request.messageSearchServerUrl,
        workId,
      )
    : null;

  return { scope: 'work', articleIds: [workId], work, messages };
}

export async function fetchAuthorExperiment(
  request: AuthorExperimentRequest,
): Promise<WorkExperimentResponse> {
  const { data } = await api.get<WorkExperimentResponse>('/work-experiment/author', {
    params: {
      author: request.author,
      q: request.messageQuery,
      keywordGraphServerUrl: request.keywordGraphServerUrl,
      messageSearchServerUrl: request.messageSearchServerUrl,
      limit: request.limit,
    },
    timeout: 120000,
  });

  return {
    ...data,
    scope: 'author',
    articleIds: Array.isArray(data.articleIds) ? data.articleIds : [],
    work: normalizeWork(data.work),
    messages: data.messages,
  };
}

async function fetchWorkKeywords(serverUrl: string, workId: string): Promise<RelatedWork> {
  const params = new URLSearchParams({ id: workId });
  const response = await fetch(joinAPIURL(serverUrl, `/api/work?${params.toString()}`), {
    cache: 'no-store',
  });
  const payload = await response.json().catch(() => null);
  if (!response.ok) {
    const message = typeof (payload as { error?: unknown } | null)?.error === 'string'
      ? (payload as { error: string }).error
      : `HTTP ${response.status}`;
    throw new Error(message);
  }
  return normalizeWork(payload as RelatedWork);
}

function normalizeWork(work: RelatedWork): RelatedWork {
  return {
    ...work,
    matched_keywords: Array.isArray(work?.matched_keywords) ? work.matched_keywords : [],
    top_keywords: Array.isArray(work?.top_keywords) ? work.top_keywords : [],
  };
}

function joinAPIURL(baseURL: string, path: string): string {
  const trimmed = baseURL.trim().replace(/\/+$/, '');
  if (!trimmed) {
    return path;
  }
  return `${trimmed}${path}`;
}
