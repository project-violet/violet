export interface Article {
  Id: number;
  Title: string;
  EHash: string | null;
  Type: string | null;
  Artists: string | null;
  Characters: string | null;
  Groups: string | null;
  Language: string | null;
  Series: string | null;
  Tags: string | null;
  Uploader: string | null;
  Published: number | string | null;
  Files: number | null;
  Class: string | null;
  PublishedEH: string | null;
  Thumbnail: string | null;
  URL: string | null;
  ExistOnHitomi: number | null;
}

export interface ArticleSearchResult {
  articles: Article[];
  totalCount: number;
  page: number;
  pageSize: number;
}

export interface SearchDateRange {
  from?: string;
  to?: string;
}

export interface DateDistributionBucket {
  start: string;
  end: string;
  count: number;
}

export interface DateDistributionResponse {
  minDate: string | null;
  maxDate: string | null;
  totalCount: number;
  invalidCount: number;
  unit: 'year' | 'month' | 'day';
  buckets: DateDistributionBucket[];
}

export interface ImageList {
  urls: string[];
  bigThumbnails: string[];
  smallThumbnails: string[];
}

export type SuggestionCategory =
  | 'artist'
  | 'tag'
  | 'male'
  | 'female'
  | 'series'
  | 'character'
  | 'group'
  | 'uploader'
  | 'lang'
  | 'type'
  | 'class';

export interface TagEntry {
  category: SuggestionCategory;
  tag: string;
  display: string;
  count: number;
  contextualCount?: number;
}

export interface SuggestionResult {
  suggestions: TagEntry[];
}

export interface SuggestionCacheStatus {
  built: boolean;
  counts: Record<string, number>;
}
