/**
 * Parse pipe-delimited tag strings like "|tag1|tag2|tag3|" into arrays.
 */
export function parsePipeTags(raw: string | null): string[] {
  if (!raw) return [];
  return raw
    .split('|')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

/**
 * Parse tags into structured tuples of [namespace, tag].
 * Tags may have format "male:tagname" or just "tagname".
 */
export function parseTagTuples(
  raw: string | null,
): Array<{ namespace: string; tag: string }> {
  const tags = parsePipeTags(raw);
  return tags.map((t) => {
    const colonIdx = t.indexOf(':');
    if (colonIdx >= 0) {
      return { namespace: t.substring(0, colonIdx), tag: t.substring(colonIdx + 1) };
    }
    return { namespace: '', tag: t };
  });
}

/**
 * Encode an array of tags back into pipe-delimited format.
 */
export function encodePipeTags(tags: string[]): string {
  if (tags.length === 0) return '';
  return '|' + tags.join('|') + '|';
}
