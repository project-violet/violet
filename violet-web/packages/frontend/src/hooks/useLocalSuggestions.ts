import { useMemo } from 'react';
import type { TagEntry } from '@violet-web/shared';
import type { TagChipData } from './useArticleTagSummary';

/**
 * Extract the last token from search input
 */
function getLastToken(input: string): string {
  const tokens = input.trim().split(/\s+/);
  return tokens[tokens.length - 1] || '';
}

/**
 * Pure function to generate autocomplete suggestions from local tag data
 * Filters TagChipData based on last token and returns top matches
 */
export function getLocalSuggestions(
  tagData: TagChipData[],
  input: string,
  limit = 10
): TagEntry[] {
  const lastToken = getLastToken(input).toLowerCase();

  if (!lastToken) {
    return [];
  }

  // Filter tags where display includes the last token (case-insensitive)
  const matches = tagData
    .filter(tag => tag.display.toLowerCase().includes(lastToken))
    .slice(0, limit);

  // Convert TagChipData to TagEntry format for SearchBar compatibility
  return matches.map(tag => ({
    category: tag.category,
    tag: tag.tag,
    display: tag.display,
    count: tag.count,
  }));
}

/**
 * Hook to generate autocomplete suggestions from local tag data
 * Filters TagChipData based on last token and returns top 10 matches
 */
export function useLocalSuggestions(
  tagData: TagChipData[],
  input: string,
  limit = 10
): TagEntry[] {
  return useMemo(
    () => getLocalSuggestions(tagData, input, limit),
    [tagData, input, limit]
  );
}
