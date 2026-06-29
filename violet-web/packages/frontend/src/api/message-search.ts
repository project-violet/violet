import type {
  MessageSearchHistoryResponse,
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
): Promise<MessageSearchResponse> {
  const { data } = await api.get<MessageSearchResponse>('/message-search', {
    params: { q: query, mode, limit, baseUrl },
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
