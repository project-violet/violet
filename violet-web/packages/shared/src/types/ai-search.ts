export interface AiSearchResultItem {
  articleId: string;
  score: number;
  description: string;
}

export interface AiSearchResponse {
  query: string;
  results: AiSearchResultItem[];
  answer: string;
}
