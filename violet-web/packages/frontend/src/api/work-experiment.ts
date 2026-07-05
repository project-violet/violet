import type { MessageSearchResponse } from '@violet-web/shared';
import type { RelatedWork } from '../types/keyword-graph';
import { messageSearch } from './message-search';

export interface WorkExperimentRequest {
  workId: string;
  messageQuery: string;
  keywordGraphServerUrl: string;
  messageSearchServerUrl: string;
  limit: number;
}

export interface WorkExperimentResponse {
  work: RelatedWork;
  messages: MessageSearchResponse | null;
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

  return { work, messages };
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
  const work = payload as RelatedWork;
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
