import { lazy, Suspense } from 'react';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import { Routes, Route } from 'react-router';
import { AppShell } from '../components/layout/AppShell';
import { HomePage } from '../pages/HomePage';
import { ArticlePage } from '../pages/ArticlePage';
import { ViewerPage } from '../pages/ViewerPage';
import { BookmarksPage } from '../pages/BookmarksPage';
import { CropBookmarksPage } from '../pages/CropBookmarksPage';
import { HistoryPage } from '../pages/HistoryPage';
import { DownloadsPage } from '../pages/DownloadsPage';
const SettingsPage = lazy(() => import('../pages/SettingsPage').then((module) => ({ default: module.SettingsPage })));
import { AiSearchPage } from '../pages/AiSearchPage';
import { MessageSearchPage } from '../pages/MessageSearchPage';
import { LlmSearchPage } from '../pages/LlmSearchPage';
import { HotPage } from '../pages/HotPage';
const KeywordGraphPage = lazy(() => import('../pages/KeywordGraphPage').then((module) => ({ default: module.KeywordGraphPage })));
const WorkExperimentPage = lazy(() => import('../pages/WorkExperimentPage').then((module) => ({ default: module.WorkExperimentPage })));
const AuthorSimilarityPage = lazy(() => import('../pages/AuthorSimilarityPage').then((module) => ({ default: module.AuthorSimilarityPage })));
const ActivityPage = lazy(() => import('../pages/ActivityPage').then((module) => ({ default: module.ActivityPage })));

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
        <Route path="llm-search" element={<LlmSearchPage />} />
        <Route path="keyword-graph" element={<Suspense fallback={<LoadingSpinner />}><KeywordGraphPage /></Suspense>} />
        <Route path="work-experiment" element={<Suspense fallback={<LoadingSpinner />}><WorkExperimentPage /></Suspense>} />
        <Route path="author-similarity" element={<Suspense fallback={<LoadingSpinner />}><AuthorSimilarityPage /></Suspense>} />
        <Route path="activity" element={<Suspense fallback={<LoadingSpinner />}><ActivityPage /></Suspense>} />
        <Route path="settings" element={<Suspense fallback={<LoadingSpinner />}><SettingsPage /></Suspense>} />
      </Route>
      <Route path="viewer/:id" element={<ViewerPage />} />
    </Routes>
  );
}
