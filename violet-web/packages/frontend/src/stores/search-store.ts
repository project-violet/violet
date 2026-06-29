import { create } from 'zustand';
import { persist } from 'zustand/middleware';

interface SearchState {
  recentSearches: string[];
  addRecentSearch: (query: string) => void;
  clearRecentSearches: () => void;
}

export const useSearchStore = create<SearchState>()(
  persist(
    (set) => ({
      recentSearches: [],
      addRecentSearch: (query) =>
        set((s) => ({
          recentSearches: [
            query,
            ...s.recentSearches.filter((q) => q !== query),
          ].slice(0, 20),
        })),
      clearRecentSearches: () => set({ recentSearches: [] }),
    }),
    { name: 'violet-search' },
  ),
);
