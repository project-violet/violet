import type {
  GraphRequest,
  KeywordGraph,
  KeywordLinksResponse,
  RelatedWorksRequest,
  RelatedWorksResponse,
} from '../types/keyword-graph';

export async function fetchKeywordGraph(
  serverUrl: string,
  request: GraphRequest,
  signal?: AbortSignal,
): Promise<KeywordGraph> {
  const params = new URLSearchParams({
    query: request.query,
    expand: request.expand,
    depth: String(request.depth),
    topN: String(request.topN),
    minScore: String(request.minScore),
    minCooccur: String(request.autoMinCooccur ? 0 : request.minCooccur),
    autoMinCooccur: request.autoMinCooccur ? '1' : '0',
    minKeywordDF: String(request.minKeywordDF),
    maxNodes: String(request.maxNodes),
  });
  const queryKeywords = parseGraphQueryKeywords(request.query);
  if (queryKeywords.length > 1) {
    for (const keyword of queryKeywords) {
      params.append('queries', keyword);
    }
  }
  const payload = await fetchJSON(joinAPIURL(serverUrl, `/api/graph?${params.toString()}`), signal);
  return normalizeKeywordGraph(payload);
}

export async function fetchRelatedWorks(
  serverUrl: string,
  request: RelatedWorksRequest,
  signal?: AbortSignal,
): Promise<RelatedWorksResponse> {
  const params = new URLSearchParams({
    mode: request.mode,
    match: request.match ?? 'soft',
    limit: String(request.limit ?? 40),
  });
  if (request.query) {
    params.set('query', request.query);
  }
  for (const keyword of request.keywords ?? []) {
    params.append('keywords', keyword);
  }
  if (request.graph) {
    params.set('expand', request.graph.expand);
    params.set('depth', String(request.graph.depth));
    params.set('topN', String(request.graph.topN));
    params.set('minScore', String(request.graph.minScore));
    params.set('minCooccur', String(request.graph.autoMinCooccur ? 0 : request.graph.minCooccur));
    params.set('autoMinCooccur', request.graph.autoMinCooccur ? '1' : '0');
    params.set('minKeywordDF', String(request.graph.minKeywordDF));
    params.set('maxNodes', String(request.graph.maxNodes));
  }
  const payload = await fetchJSON(joinAPIURL(serverUrl, `/api/works?${params.toString()}`), signal);
  return normalizeRelatedWorks(payload);
}

export async function fetchKeywordLinks(
  serverUrl: string,
  request: { keywords: string[]; minKeywordDF?: number; minCooccur?: number; limit?: number },
  signal?: AbortSignal,
): Promise<KeywordLinksResponse> {
  const params = new URLSearchParams({
    minKeywordDF: String(request.minKeywordDF ?? 1),
    minCooccur: String(request.minCooccur ?? 1),
    limit: String(request.limit ?? 80),
  });
  for (const keyword of request.keywords) {
    params.append('keywords', keyword);
  }
  const payload = await fetchJSON(joinAPIURL(serverUrl, `/api/links?${params.toString()}`), signal);
  return normalizeKeywordLinks(payload);
}

export function normalizeKeywordGraph(payload: unknown): KeywordGraph {
  const graph = payload as KeywordGraph;
  return {
    ...graph,
    nodes: Array.isArray(graph?.nodes) ? graph.nodes : [],
    edges: Array.isArray(graph?.edges) ? graph.edges : [],
  };
}

export function normalizeKeywordLinks(payload: unknown): KeywordLinksResponse {
  const response = payload as KeywordLinksResponse;
  return {
    ...response,
    query_terms: Array.isArray(response?.query_terms) ? response.query_terms : [],
    links: Array.isArray(response?.links) ? response.links : [],
  };
}

export function normalizeRelatedWorks(payload: unknown): RelatedWorksResponse {
  const response = payload as RelatedWorksResponse;
  return {
    ...response,
    query_terms: Array.isArray(response?.query_terms) ? response.query_terms : [],
    works: Array.isArray(response?.works) ? response.works : [],
  };
}

async function fetchJSON(url: string, signal?: AbortSignal): Promise<unknown> {
  const response = await fetch(url, { signal });
  const payload = await response.json().catch(() => null);
  if (!response.ok) {
    const message = typeof (payload as { error?: unknown } | null)?.error === 'string'
      ? (payload as { error: string }).error
      : `HTTP ${response.status}`;
    throw new Error(message);
  }
  return payload;
}

function joinAPIURL(baseURL: string, path: string): string {
  const trimmed = baseURL.trim().replace(/\/+$/, '');
  if (!trimmed) {
    return path;
  }
  return `${trimmed}${path}`;
}

function parseGraphQueryKeywords(query: string): string[] {
  const seen = new Set<string>();
  const keywords: string[] = [];
  for (const part of query.split(/[|,]/)) {
    const keyword = part.trim();
    if (!keyword || seen.has(keyword)) {
      continue;
    }
    seen.add(keyword);
    keywords.push(keyword);
  }
  return keywords;
}
