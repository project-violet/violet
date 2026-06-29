import { useState, useEffect } from 'react';
import { fetchTagCounts } from '../api/content';

let cache: Record<string, number> | null = null;
let loading = false;
let waiters: Array<(v: Record<string, number>) => void> = [];

function load(): Promise<Record<string, number>> {
  if (cache) return Promise.resolve(cache);
  return new Promise((resolve) => {
    waiters.push(resolve);
    if (loading) return;
    loading = true;
    fetchTagCounts().then((data) => {
      cache = data;
      loading = false;
      for (const w of waiters) w(data);
      waiters = [];
    });
  });
}

export function useTagCounts() {
  const [counts, setCounts] = useState<Record<string, number> | null>(cache);

  useEffect(() => {
    if (cache) {
      setCounts(cache);
      return;
    }
    load().then(setCounts);
  }, []);

  return counts;
}
