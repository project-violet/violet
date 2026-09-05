import type {
  MessageSearchHistoryResponse,
  MessageSearchFilters,
  MessageSearchMode,
  MessageSearchResponse,
  MessageSearchStatusResponse,
} from '@violet-web/shared';
import { api } from './client';

export async function messageSearch(
  query: string,
  mode: MessageSearchMode,
  limit = 100,
  baseUrl?: string,
  articleId?: string,
  filters: MessageSearchFilters = {},
): Promise<MessageSearchResponse> {
  const { data } = await api.get<MessageSearchResponse>('/message-search', {
    params: { q: query, mode, limit, baseUrl, articleId, ...filters },
  });
  return data;
}

export async function getMessageSearchStatus(
  baseUrl?: string,
): Promise<MessageSearchStatusResponse> {
  const { data } = await api.get<MessageSearchStatusResponse>('/message-search/status', {
    params: { baseUrl },
  });
  return data;
}

export async function fetchMessageSearchHistory(
  query: string,
  limit?: number,
): Promise<MessageSearchHistoryResponse> {
  const { data } = await api.get<MessageSearchHistoryResponse>('/message-search/history', {
    params: { q: query, ...(limit === undefined ? {} : { limit }) },
  });
  return data;
}

export async function recordMessageSearchHistory(query: string): Promise<void> {
  await api.post('/message-search/history', { query });
}

export async function scopedMessageSearch(query: string, mode: MessageSearchMode, ids: number[], limit: number, baseUrl: string, signal?: AbortSignal): Promise<MessageSearchResponse> {
  const { data } = await api.post<MessageSearchResponse>('/message-search/scoped', { q: query, mode, ids, limit, baseUrl }, { signal });
  return data;
}
