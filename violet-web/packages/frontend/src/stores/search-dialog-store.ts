import { create } from 'zustand';

interface SearchDialogState {
  query: string | null;
  page: number;
  open: (query: string) => void;
  setPage: (page: number) => void;
  close: () => void;
}

function syncUrl(query: string | null, page: number) {
  const url = new URL(window.location.href);
  if (query) {
    url.searchParams.set('sdq', query);
    if (page > 0) url.searchParams.set('sdp', String(page));
    else url.searchParams.delete('sdp');
  } else {
    url.searchParams.delete('sdq');
    url.searchParams.delete('sdp');
  }
  window.history.replaceState(window.history.state, '', url.toString());
}

export const useSearchDialogStore = create<SearchDialogState>((set) => ({
  query: null,
  page: 0,
  open: (query) => {
    set({ query, page: 0 });
    syncUrl(query, 0);
  },
  setPage: (page) => {
    set({ page });
    const q = useSearchDialogStore.getState().query;
    syncUrl(q, page);
  },
  close: () => {
    set({ query: null, page: 0 });
    syncUrl(null, 0);
  },
}));

/** Read sdq/sdp from current URL (call on mount to restore after back-navigation) */
export function restoreSearchDialogFromUrl() {
  const params = new URLSearchParams(window.location.search);
  const sdq = params.get('sdq');
  if (sdq) {
    const sdp = parseInt(params.get('sdp') || '0') || 0;
    useSearchDialogStore.setState({ query: sdq, page: sdp });
  }
}
