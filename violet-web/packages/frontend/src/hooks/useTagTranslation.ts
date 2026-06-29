import { useState, useEffect, useCallback } from 'react';
import { useAppStore } from '../stores/app-store';

let cache: Record<string, string> | null = null;

export function useTagTranslation() {
  const tagTranslation = useAppStore((s) => s.tagTranslation);
  const [dict, setDict] = useState<Record<string, string> | null>(cache);

  useEffect(() => {
    if (!tagTranslation) return;
    if (cache) {
      setDict(cache);
      return;
    }
    import('../data/tag-ko.json').then((m) => {
      cache = m.default;
      setDict(m.default);
    });
  }, [tagTranslation]);

  const translateTag = useCallback(
    (namespace: string, tag: string): string | undefined => {
      if (!dict) return undefined;
      const val = namespace
        ? (dict[`tag:${namespace}:${tag}`] ?? dict[`${namespace}:${tag}`])
        : dict[`tag:${tag}`];
      if (!val) return undefined;
      const idx = val.indexOf(':');
      return idx >= 0 ? val.slice(idx + 1) : val;
    },
    [dict],
  );

  return { translateTag, enabled: tagTranslation && dict != null };
}
