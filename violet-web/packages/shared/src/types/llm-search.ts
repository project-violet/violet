export interface LlmSearchResult {
  rank: number;
  rerankScore: number | null;
  embedScore: number;
  work: number;
  pages: number[];
}

export interface LlmSearchResponse {
  query: string;
  topK: number;
  candidateK: number;
  elapsedMs: number;
  total: number;
  results: LlmSearchResult[];
}

export interface LlmSearchStatusResponse {
  ok: boolean;
  baseUrl: string;
  works?: number;
  vectors?: number;
  dimensions?: number;
  error?: string;
}

export interface LlmSearchHistoryEntry {
  query: string;
  topK: number;
  candidateK: number;
  searchCount: number;
  lastSearchedAt: string;
}

export interface LlmSearchHistoryResponse {
  items: LlmSearchHistoryEntry[];
}
