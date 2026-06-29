import { BrowserRouter } from 'react-router';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { AppRoutes } from './router';
import { ThemeProvider } from './components/ThemeProvider';
import { DbDownloadOverlay } from './components/common/DbDownloadOverlay';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000,
      retry: 1,
    },
  },
});

export function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <ThemeProvider />
        <DbDownloadOverlay />
        <AppRoutes />
      </BrowserRouter>
    </QueryClientProvider>
  );
}
