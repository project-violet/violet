import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { fetchContextualSuggestions } from '../api/content';

function splitSuggestionInput(input: string): { base: string; partial: string } {
  const trimmed = input.trim();
  if (!trimmed) return { base: '', partial: '' };

  const tokens = trimmed.split(/\s+/);
  const partial = tokens[tokens.length - 1] || '';
  const base = tokens.slice(0, -1).join(' ');

  return { base, partial };
}

export function useContextualSuggestions(input: string, contextQuery = '', limit = 20) {
  const { base, partial } = useMemo(() => splitSuggestionInput(input), [input]);
  const contextualBase = useMemo(
    () => [base, contextQuery.trim()].filter(Boolean).join(' '),
    [base, contextQuery],
  );

  return useQuery({
    queryKey: ['contextual-suggestions', contextualBase, partial, limit],
    queryFn: () => fetchContextualSuggestions(partial, contextualBase, limit),
    enabled: partial.length > 0,
    staleTime: 60000,
  });
}
