import { useMemo } from 'react';
import { useSearchParams } from 'react-router';
import type { Article } from '@violet-web/shared';
import { parsePipeTags, parseTagTuples } from '@violet-web/shared';

interface ParsedToken {
  type: 'structured' | 'plain';
  field?: string; // for structured queries like "artist:xxx"
  value: string;
}

function normalizeSearchValue(value: string): string {
  return value.replace(/_/g, ' ');
}

/**
 * Parse a search query into tokens
 * Supports structured queries: artist:xxx, tag:xxx, series:xxx, character:xxx, group:xxx, male:xxx, female:xxx
 */
function parseQuery(query: string): ParsedToken[] {
  const tokens = query.trim().toLowerCase().split(/\s+/).filter(Boolean);

  return tokens.map(token => {
    const colonIdx = token.indexOf(':');
    if (colonIdx > 0) {
      const field = token.substring(0, colonIdx);
      const value = token.substring(colonIdx + 1);

      // Check if it's a valid structured query
      const validFields = ['artist', 'tag', 'series', 'character', 'group', 'male', 'female', 'lang', 'type', 'class', 'uploader'];
      if (validFields.includes(field) && value) {
        return { type: 'structured', field, value };
      }
    }

    // Default to plain token
    return { type: 'plain', value: token };
  });
}

/**
 * Check if an article matches a single token
 */
function matchesToken(article: Article, token: ParsedToken): boolean {
  const { type, field, value } = token;

  if (type === 'structured' && field) {
    const normalizedValue = normalizeSearchValue(value);
    // Structured query - match specific field
    switch (field) {
      case 'artist': {
        const artists = parsePipeTags(article.Artists).map(a => a.toLowerCase());
        return artists.some(a => a.includes(normalizedValue));
      }
      case 'series': {
        const series = parsePipeTags(article.Series).map(s => s.toLowerCase());
        return series.some(s => s.includes(normalizedValue));
      }
      case 'character': {
        const characters = parsePipeTags(article.Characters).map(c => c.toLowerCase());
        return characters.some(c => c.includes(normalizedValue));
      }
      case 'group': {
        const groups = parsePipeTags(article.Groups).map(g => g.toLowerCase());
        return groups.some(g => g.includes(normalizedValue));
      }
      case 'tag':
      case 'male':
      case 'female': {
        const tags = parseTagTuples(article.Tags).map(t => {
          const fullTag = t.namespace ? `${t.namespace}:${t.tag}` : t.tag;
          return fullTag.toLowerCase();
        });

        if (field === 'male') {
          return tags.some(t => t.startsWith('male:') && t.includes(normalizedValue));
        }
        if (field === 'female') {
          return tags.some(t => t.startsWith('female:') && t.includes(normalizedValue));
        }
        // For general tag search, match any tag
        return tags.some(t => t.includes(normalizedValue));
      }
      case 'lang':
        return article.Language?.toLowerCase().includes(value) ?? false;
      case 'type':
        return article.Type?.toLowerCase().includes(value) ?? false;
      case 'class':
        return article.Class?.toLowerCase().includes(value) ?? false;
      case 'uploader':
        return article.Uploader?.toLowerCase().includes(value) ?? false;
    }
  }

  // Plain token - search across all text fields
  const searchIn = [
    article.Title?.toLowerCase() ?? '',
    ...parsePipeTags(article.Artists).map(a => a.toLowerCase()),
    ...parsePipeTags(article.Series).map(s => s.toLowerCase()),
    ...parsePipeTags(article.Characters).map(c => c.toLowerCase()),
    ...parsePipeTags(article.Groups).map(g => g.toLowerCase()),
    ...parseTagTuples(article.Tags).map(t => {
      const fullTag = t.namespace ? `${t.namespace}:${t.tag}` : t.tag;
      return fullTag.toLowerCase();
    }),
  ];

  return searchIn.some(text => text.includes(value));
}

/**
 * Hook to search articles locally based on URL query parameter
 * Returns filtered articles if query exists, otherwise returns all articles
 */
export function useLocalArticleSearch(articles: Article[]): Article[] {
  const [searchParams] = useSearchParams();
  const query = searchParams.get('q') || '';

  return useMemo(() => {
    if (!query.trim()) {
      return articles;
    }

    const tokens = parseQuery(query);

    // AND matching - all tokens must match
    return articles.filter(article =>
      tokens.every(token => matchesToken(article, token))
    );
  }, [articles, query]);
}
