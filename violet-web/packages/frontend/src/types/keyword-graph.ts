export type ExpandMode = 'none' | 'contains';

export interface GraphParams {
  expand: ExpandMode;
  depth: number;
  top_n: number;
  min_score: number;
  min_cooccur: number;
  auto_min_cooccur: boolean;
  min_keyword_df: number;
  max_nodes: number;
}

export interface KeywordNode {
  id: string;
  label: string;
  depth: number;
  df: number;
}

export interface KeywordEdge {
  id: string;
  from: string;
  to: string;
  score: number;
  cooccur: number;
  query_df: number;
  keyword_df: number;
}

export interface KeywordGraph {
  query: string;
  queries?: string[];
  params: GraphParams;
  nodes: KeywordNode[];
  edges: KeywordEdge[];
}

export interface KeywordLink {
  keyword: string;
  score: number;
  cooccur: number;
  keyword_df: number;
}

export interface KeywordLinksResponse {
  query: string;
  query_terms: string[];
  links: KeywordLink[];
}

export interface GraphRequest {
  query: string;
  expand: ExpandMode;
  depth: number;
  topN: number;
  minScore: number;
  minCooccur: number;
  autoMinCooccur: boolean;
  minKeywordDF: number;
  maxNodes: number;
}

export type RelatedWorksMode = 'graph' | 'selected';
export type RelatedWorksMatch = 'soft' | 'all';

export interface RelatedWorkKeyword {
  keyword: string;
  score: number;
  rank: number;
  tf: number;
}

export interface RelatedWork {
  article_id: string;
  score: number;
  matched_count: number;
  matched_keywords: RelatedWorkKeyword[];
  top_keywords: RelatedWorkKeyword[];
  total_pages: number;
  dialogue_count: number;
  char_count: number;
}

export interface RelatedWorksResponse {
  query: string;
  mode: RelatedWorksMode;
  match: RelatedWorksMatch;
  query_terms: string[];
  works: RelatedWork[];
}

export interface RelatedWorksRequest {
  mode: RelatedWorksMode;
  query?: string;
  keywords?: string[];
  match?: RelatedWorksMatch;
  graph?: GraphRequest;
  limit?: number;
}
