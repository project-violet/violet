import { readFileSync, writeFileSync, existsSync } from 'fs';
import { join } from 'path';
import type { Database } from 'better-sqlite3';

const CACHE_FILE = join(process.cwd(), 'suggestion-cache.json');

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
}

let cache: TagEntry[] | null = null;

/**
 * Parse pipe-delimited tags from a column value
 */
function parsePipeTags(value: string | null): string[] {
  if (!value) return [];
  return value
    .split('|')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

/**
 * Normalize tag name by replacing spaces with underscores
 */
function normalizeTag(tag: string): string {
  return tag.replace(/\s+/g, '_');
}

/**
 * Build the suggestion cache from database
 */
export function buildSuggestionCache(db: Database): void {
  const countMaps = {
    artist: new Map<string, number>(),
    tag: new Map<string, number>(),
    male: new Map<string, number>(),
    female: new Map<string, number>(),
    series: new Map<string, number>(),
    character: new Map<string, number>(),
    group: new Map<string, number>(),
    uploader: new Map<string, number>(),
    lang: new Map<string, number>(),
    type: new Map<string, number>(),
    class: new Map<string, number>(),
  };

  // Collect from pipe-delimited columns and count occurrences
  // Use .iterate() instead of .all() to avoid loading all rows into memory at once
  const stmt = db.prepare(
    'SELECT Artists, Tags, Series, Characters, Groups, Uploader, Language, Type, Class FROM HitomiColumnModel'
  );

  for (const row of stmt.iterate() as IterableIterator<{
    Artists: string | null;
    Tags: string | null;
    Series: string | null;
    Characters: string | null;
    Groups: string | null;
    Uploader: string | null;
    Language: string | null;
    Type: string | null;
    Class: string | null;
  }>) {
    // Artists
    parsePipeTags(row.Artists).forEach((a) => {
      const normalized = normalizeTag(a);
      countMaps.artist.set(normalized, (countMaps.artist.get(normalized) || 0) + 1);
    });

    // Tags (including namespaced tags)
    parsePipeTags(row.Tags).forEach((tag) => {
      if (tag.startsWith('male:')) {
        const maleTag = normalizeTag(tag.substring(5));
        countMaps.male.set(maleTag, (countMaps.male.get(maleTag) || 0) + 1);
      } else if (tag.startsWith('female:')) {
        const femaleTag = normalizeTag(tag.substring(7));
        countMaps.female.set(femaleTag, (countMaps.female.get(femaleTag) || 0) + 1);
      } else {
        const normalized = normalizeTag(tag);
        countMaps.tag.set(normalized, (countMaps.tag.get(normalized) || 0) + 1);
      }
    });

    // Series
    parsePipeTags(row.Series).forEach((s) => {
      const normalized = normalizeTag(s);
      countMaps.series.set(normalized, (countMaps.series.get(normalized) || 0) + 1);
    });

    // Characters
    parsePipeTags(row.Characters).forEach((c) => {
      const normalized = normalizeTag(c);
      countMaps.character.set(normalized, (countMaps.character.get(normalized) || 0) + 1);
    });

    // Groups
    parsePipeTags(row.Groups).forEach((g) => {
      const normalized = normalizeTag(g);
      countMaps.group.set(normalized, (countMaps.group.get(normalized) || 0) + 1);
    });

    // Uploader (single value)
    if (row.Uploader) {
      const normalized = normalizeTag(row.Uploader);
      countMaps.uploader.set(normalized, (countMaps.uploader.get(normalized) || 0) + 1);
    }

    // Language (single value)
    if (row.Language) {
      const normalized = normalizeTag(row.Language);
      countMaps.lang.set(normalized, (countMaps.lang.get(normalized) || 0) + 1);
    }

    // Type (single value)
    if (row.Type) {
      const normalized = normalizeTag(row.Type);
      countMaps.type.set(normalized, (countMaps.type.get(normalized) || 0) + 1);
    }

    // Class (single value)
    if (row.Class) {
      const normalized = normalizeTag(row.Class);
      countMaps.class.set(normalized, (countMaps.class.get(normalized) || 0) + 1);
    }
  }

  // Convert maps to TagEntry array and flatten
  const allEntries: TagEntry[] = [];

  for (const [category, countMap] of Object.entries(countMaps)) {
    for (const [tag, count] of countMap.entries()) {
      allEntries.push({
        category: category as SuggestionCategory,
        tag,
        display: `${category}:${tag}`,
        count,
      });
    }
  }

  // Sort by count descending
  cache = allEntries.sort((a, b) => b.count - a.count);

  // Persist to file
  try {
    writeFileSync(CACHE_FILE, JSON.stringify(cache));
  } catch (e) {
    console.warn('Failed to write suggestion cache file:', e);
  }

  console.log('Suggestion cache built:', {
    totalEntries: cache.length,
    topEntry: cache[0] ? `${cache[0].display} (${cache[0].count})` : 'none',
  });
}

/**
 * Load suggestion cache from file if available
 * Returns true if cache was loaded, false otherwise
 */
export function loadSuggestionCacheFromFile(): boolean {
  if (cache) return true;
  try {
    if (existsSync(CACHE_FILE)) {
      cache = JSON.parse(readFileSync(CACHE_FILE, 'utf-8'));
      console.log('Suggestion cache loaded from file:', {
        totalEntries: cache!.length,
      });
      return true;
    }
  } catch (e) {
    console.warn('Failed to load suggestion cache file:', e);
  }
  return false;
}

/**
 * Search suggestions based on query
 * Handles both category:prefix format and bare text search
 */
export function searchSuggestions(query: string, limit = 20): TagEntry[] {
  if (!cache) return [];

  const normalizedQuery = query.toLowerCase().trim();
  if (!normalizedQuery) return [];

  // Parse query to check for category:prefix format
  const match = normalizedQuery.match(
    /^(female|male|tag|lang|series|artist|group|uploader|character|type|class):(.*)$/
  );

  if (match) {
    // Category-specific search
    const category = match[1] as SuggestionCategory;
    const prefix = match[2];

    if (prefix === '') {
      // Empty prefix: return top entries from this category
      return cache
        .filter((entry) => entry.category === category)
        .slice(0, limit);
    } else {
      // Prefix search within category
      return cache
        .filter(
          (entry) =>
            entry.category === category &&
            entry.tag.toLowerCase().startsWith(prefix)
        )
        .slice(0, limit);
    }
  } else {
    // Global search across all categories
    return cache
      .filter(
        (entry) =>
          entry.tag.toLowerCase().includes(normalizedQuery) ||
          entry.display.toLowerCase().includes(normalizedQuery)
      )
      .slice(0, limit);
  }
}

/**
 * Invalidate the suggestion cache
 */
export function invalidateSuggestionCache(): void {
  cache = null;
  tagCountsCache = null;
}

/**
 * Get tag counts for female/male/tag categories as a minimal map
 */
let tagCountsCache: Record<string, number> | null = null;

export function getTagCounts(): Record<string, number> {
  if (tagCountsCache) return tagCountsCache;
  if (!cache) return {};
  const map: Record<string, number> = {};
  for (const entry of cache) {
    if (entry.category === 'female' || entry.category === 'male' || entry.category === 'tag') {
      map[entry.display] = entry.count;
    }
  }
  tagCountsCache = map;
  return map;
}

/**
 * Check if cache is built
 */
export function isCacheBuilt(): boolean {
  return cache !== null;
}

/**
 * Get cache status
 */
export function getCacheStatus(): { built: boolean; counts: Record<string, number> } {
  if (!cache) {
    return { built: false, counts: {} };
  }

  const counts: Record<string, number> = {};
  for (const entry of cache) {
    counts[entry.category] = (counts[entry.category] || 0) + 1;
  }

  return {
    built: true,
    counts,
  };
}
