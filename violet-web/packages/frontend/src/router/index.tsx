import { Routes, Route } from 'react-router';
import { AppShell } from '../components/layout/AppShell';
import { HomePage } from '../pages/HomePage';
import { ArticlePage } from '../pages/ArticlePage';
import { ViewerPage } from '../pages/ViewerPage';
import { BookmarksPage } from '../pages/BookmarksPage';
import { CropBookmarksPage } from '../pages/CropBookmarksPage';
import { HistoryPage } from '../pages/HistoryPage';
import { DownloadsPage } from '../pages/DownloadsPage';
import { SettingsPage } from '../pages/SettingsPage';
import { AiSearchPage } from '../pages/AiSearchPage';
import { MessageSearchPage } from '../pages/MessageSearchPage';
import { HotPage } from '../pages/HotPage';
import { KeywordGraphPage } from '../pages/KeywordGraphPage';

export function AppRoutes() {
  return (
    <Routes>
      <Route element={<AppShell />}>
        <Route index element={<HomePage />} />
        <Route path="article/:id" element={<ArticlePage />} />
        <Route path="bookmarks" element={<BookmarksPage />} />
        <Route path="crop-bookmarks" element={<CropBookmarksPage />} />
        <Route path="history" element={<HistoryPage />} />
        <Route path="downloads" element={<DownloadsPage />} />
        <Route path="hot" element={<HotPage />} />
        <Route path="ai-search" element={<AiSearchPage />} />
        <Route path="message-search" element={<MessageSearchPage />} />
        <Route path="keyword-graph" element={<KeywordGraphPage />} />
        <Route path="settings" element={<SettingsPage />} />
      </Route>
      <Route path="viewer/:id" element={<ViewerPage />} />
    </Routes>
  );
}
