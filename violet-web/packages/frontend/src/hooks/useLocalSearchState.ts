import { useState, useRef, useEffect, useCallback } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import type { SearchBarRef } from '../components/search/SearchBar';
import type { TagChipData } from './useArticleTagSummary';
import { getLocalSuggestions } from './useLocalSuggestions';
import type { TagEntry } from '@violet-web/shared';

interface UseLocalSearchStateOptions {
  basePath: string;
  tagSummary: TagChipData[];
  onReset?: () => void;
  preserveParams?: string[]; // Query parameters to preserve when updating search
}

export function useLocalSearchState({ basePath, tagSummary, onReset, preserveParams = [] }: UseLocalSearchStateOptions) {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const [selectedTags, setSelectedTags] = useState<Set<string>>(new Set());
  const searchBarRef = useRef<SearchBarRef>(null);
  const onResetRef = useRef(onReset);
  onResetRef.current = onReset;

  // Create suggestions function for SearchBar
  const getSuggestions = useCallback(
    (input: string): TagEntry[] => getLocalSuggestions(tagSummary, input),
    [tagSummary]
  );

  // Handle "/" key to focus search bar
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement;
      if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA') {
        return;
      }
      if (e.key === '/') {
        e.preventDefault();
        searchBarRef.current?.focus();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  // Handle tag chip toggle
  const handleTagToggle = useCallback(
    (display: string) => {
      setSelectedTags((prev) => {
        const newSelected = new Set(prev);
        if (newSelected.has(display)) {
          newSelected.delete(display);
        } else {
          newSelected.add(display);
        }

        // Update URL with selected tags while preserving other params
        const newParams = new URLSearchParams();

        // Preserve specified parameters (like 'p' for pagination)
        preserveParams.forEach((param) => {
          const value = searchParams.get(param);
          if (value) {
            newParams.set(param, value);
          }
        });

        // Set or delete the query parameter
        const tags = Array.from(newSelected).join(' ');
        if (tags) {
          newParams.set('q', tags);
        } else {
          newParams.delete('q');
        }

        const search = newParams.toString();
        navigate(`${basePath}${search ? `?${search}` : ''}`);

        return newSelected;
      });
    },
    [basePath, navigate, searchParams, preserveParams]
  );

  // Reset selected tags when needed
  const resetTags = useCallback(() => {
    setSelectedTags(new Set());
    onResetRef.current?.();
  }, []);

  return {
    selectedTags,
    searchBarRef,
    getSuggestions,
    handleTagToggle,
    resetTags,
  };
}
