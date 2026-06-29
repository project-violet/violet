import type { AiSearchResponse } from '@violet-web/shared';
import { api } from './client';

export async function aiSearch(query: string, topK = 5, mode = 'fast'): Promise<AiSearchResponse> {
  const { data } = await api.get<AiSearchResponse>('/ai-search', {
    params: { q: query, top_k: topK, mode },
  });
  return data;
}
