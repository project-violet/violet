import { useMemo } from 'react';
import type { Article, TagEntry, SuggestionCategory } from '@violet-web/shared';
import { parsePipeTags, parseTagTuples } from '@violet-web/shared';

export interface TagChipData {
  category: SuggestionCategory;
  tag: string;
  display: string;
  count: number;
}

function toQueryToken(tag: string): string {
  return tag.replace(/\s+/g, '_');
}

/**
 * Extract and aggregate tags from an array of articles
 * Returns top 30 tags sorted by count (descending)
 */
export function useArticleTagSummary(articles: Article[]): TagChipData[] {
  return useMemo(() => {
    const tagMap = new Map<string, { category: SuggestionCategory; tag: string; count: number }>();

    articles.forEach((article) => {
      // Artists
      parsePipeTags(article.Artists).forEach((artist) => {
        const key = `artist:${artist}`;
        const existing = tagMap.get(key);
        if (existing) {
          existing.count++;
        } else {
          tagMap.set(key, { category: 'artist', tag: artist, count: 1 });
        }
      });

      // Series
      parsePipeTags(article.Series).forEach((series) => {
        const key = `series:${series}`;
        const existing = tagMap.get(key);
        if (existing) {
          existing.count++;
        } else {
          tagMap.set(key, { category: 'series', tag: series, count: 1 });
        }
      });

      // Characters
      parsePipeTags(article.Characters).forEach((character) => {
        const key = `character:${character}`;
        const existing = tagMap.get(key);
        if (existing) {
          existing.count++;
        } else {
          tagMap.set(key, { category: 'character', tag: character, count: 1 });
        }
      });

      // Groups
      parsePipeTags(article.Groups).forEach((group) => {
        const key = `group:${group}`;
        const existing = tagMap.get(key);
        if (existing) {
          existing.count++;
        } else {
          tagMap.set(key, { category: 'group', tag: group, count: 1 });
        }
      });

      // Tags (with namespace support for male:/female:)
      parseTagTuples(article.Tags).forEach(({ namespace, tag }) => {
        const category: SuggestionCategory = namespace === 'male' ? 'male' : namespace === 'female' ? 'female' : 'tag';
        const displayTag = namespace ? `${namespace}:${tag}` : tag;
        const key = `tag:${displayTag}`;
        const existing = tagMap.get(key);
        if (existing) {
          existing.count++;
        } else {
          // Store original tag without namespace for consistency with other categories
          tagMap.set(key, { category, tag, count: 1 });
        }
      });
    });

    // Convert map to array and sort by count descending
    const sorted = Array.from(tagMap.values())
      .sort((a, b) => b.count - a.count)
      .slice(0, 30);

    // Convert to TagChipData format with display string
    return sorted.map((item) => ({
      category: item.category,
      tag: item.tag,
      display: `${item.category}:${toQueryToken(item.tag)}`,
      count: item.count,
    }));
  }, [articles]);
}
