import type {
  Article,
  ArticleSearchResult,
  SuggestionResult,
  SuggestionCacheStatus,
  TagEntry,
  SearchDateRange,
  DateDistributionResponse,
} from '@violet-web/shared';
import { api } from './client';

export async function searchArticles(
  query: string,
  page = 0,
  pageSize = 30,
  dateRange: SearchDateRange = {},
): Promise<ArticleSearchResult> {
  const { data } = await api.get<ArticleSearchResult>('/content/search', {
    params: { q: query, page, pageSize, ...dateRange },
  });
  return data;
}

export async function fetchDateDistribution(
  query: string,
  signal?: AbortSignal,
): Promise<DateDistributionResponse> {
  const { data } = await api.get<DateDistributionResponse>(
    '/content/search/date-distribution',
    { params: { q: query }, signal },
  );
  return data;
}

export async function getArticle(id: number): Promise<Article> {
  const { data } = await api.get<Article>(`/content/${id}`);
  return data;
}

export async function getArticlesBatch(ids: number[]): Promise<Article[]> {
  const { data } = await api.post<{ articles: Article[] }>('/content/batch', { ids });
  return data.articles;
}

export async function fetchSuggestions(
  q: string,
  limit = 20
): Promise<SuggestionResult> {
  const { data } = await api.get<SuggestionResult>('/content/suggest', {
    params: { q, limit },
  });
  return data;
}

export async function fetchContextualSuggestions(
  q: string,
  base: string,
  limit = 20
): Promise<SuggestionResult> {
  const { data } = await api.get<SuggestionResult>('/content/suggest/contextual', {
    params: { q, base, limit },
  });
  return data;
}

export async function fetchSearchTagSummary(
  query: string,
  limit = 30,
): Promise<TagEntry[]> {
  const { data } = await api.get<{ tags: TagEntry[] }>('/content/search/tags', {
    params: { q: query, limit },
  });
  return data.tags;
}

export async function rebuildSuggestionCache(): Promise<{ success: boolean }> {
  const { data } = await api.post<{ success: boolean }>('/content/suggest/rebuild');
  return data;
}

export async function getSuggestionCacheStatus(): Promise<SuggestionCacheStatus> {
  const { data } = await api.get<SuggestionCacheStatus>('/content/suggest/status');
  return data;
}

export async function fetchTagCounts(): Promise<Record<string, number>> {
  const { data } = await api.get<Record<string, number>>('/content/suggest/tag-counts');
  return data;
}
