import { useMemo } from 'react';
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { fetchContextualSuggestions, fetchSuggestions } from '../api/content';
import { shouldUseContextualSuggestions } from './suggestion-mode.js';

function splitSuggestionInput(input: string): { base: string; partial: string } {
  const trimmed = input.trim();
  if (!trimmed) return { base: '', partial: '' };

  const tokens = trimmed.split(/\s+/);
  const partial = tokens[tokens.length - 1] || '';
  const base = tokens.slice(0, -1).join(' ');

  return { base, partial };
}

export function useContextualSuggestions(
  input: string,
  contextQuery = '',
  limit = 20,
  contextualCountsEnabled = false,
) {
  const { base, partial } = useMemo(() => splitSuggestionInput(input), [input]);
  const contextualBase = useMemo(
    () => [base, contextQuery.trim()].filter(Boolean).join(' '),
    [base, contextQuery],
  );
  const useContextual = shouldUseContextualSuggestions(contextualCountsEnabled, partial, contextualBase);

  return useQuery({
    queryKey: useContextual
      ? ['contextual-suggestions', contextualBase, partial, limit]
      : ['suggestions', partial, limit],
    queryFn: () => useContextual
      ? fetchContextualSuggestions(partial, contextualBase, limit)
      : fetchSuggestions(partial, limit),
    enabled: partial.length > 0,
    placeholderData: keepPreviousData,
    staleTime: 60000,
  });
}