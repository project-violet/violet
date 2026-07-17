import type {
  LlmSearchHistoryResponse,
  LlmSearchResponse,
  LlmSearchStatusResponse,
} from '@violet-web/shared';
import { api } from './client';

export async function llmSearch(
  query: string,
  topK: number,
  candidateK: number,
  baseUrl: string,
): Promise<LlmSearchResponse> {
  const { data } = await api.post<LlmSearchResponse>('/llm-search', {
    query,
    topK,
    candidateK,
    baseUrl,
  });
  return data;
}

export async function getLlmSearchStatus(baseUrl: string): Promise<LlmSearchStatusResponse> {
  const { data } = await api.get<LlmSearchStatusResponse>('/llm-search/status', {
    params: { baseUrl },
  });
  return data;
}

export async function fetchLlmSearchHistory(
  query: string,
  limit?: number,
): Promise<LlmSearchHistoryResponse> {
  const { data } = await api.get<LlmSearchHistoryResponse>('/llm-search/history', {
    params: { q: query, ...(limit === undefined ? {} : { limit }) },
  });
  return data;
}

export async function recordLlmSearchHistory(
  query: string,
  topK: number,
  candidateK: number,
): Promise<void> {
  await api.post('/llm-search/history', { query, topK, candidateK });
}
