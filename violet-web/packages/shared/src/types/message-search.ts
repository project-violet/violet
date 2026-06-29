export type MessageSearchMode = 'contains' | 'similar' | 'lcs';

export type MessageSearchRect = [number, number, number, number];

export interface MessageSearchResult {
  articleId: number;
  page: number;
  rect: MessageSearchRect;
  matchScore: number | string;
  correctness: number;
}

export interface MessageSearchResponse {
  query: string;
  mode: MessageSearchMode;
  total: number;
  results: MessageSearchResult[];
}

export interface MessageSearchStatusResponse {
  ok: boolean;
  baseUrl: string;
  sampleCount?: number;
  error?: string;
}

export interface MessageSearchHistoryEntry {
  query: string;
  searchCount: number;
  lastSearchedAt: string;
}

export interface MessageSearchHistoryResponse {
  items: MessageSearchHistoryEntry[];
}
