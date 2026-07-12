import { useEffect, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { fetchDateDistribution } from '../api/content';

export function useDateDistribution(query: string, enabled = true) {
  const [debouncedQuery, setDebouncedQuery] = useState(query);

  useEffect(() => {
    const timer = window.setTimeout(() => setDebouncedQuery(query), 250);
    return () => window.clearTimeout(timer);
  }, [query]);

  return useQuery({
    queryKey: ['date-distribution', debouncedQuery],
    queryFn: ({ signal }) => fetchDateDistribution(debouncedQuery, signal),
    enabled: enabled && debouncedQuery.length > 0,
    staleTime: 60_000,
  });
}
