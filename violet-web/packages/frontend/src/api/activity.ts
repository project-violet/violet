import { api } from './client';

export type ActivityType = 'read' | 'bookmark' | 'crop' | 'download';

export interface ActivityDay {
  date: string;
  reads: number;
  bookmarks: number;
  crops: number;
  downloads: number;
  total: number;
}

export interface UserActivity {
  totals: {
    reads: number;
    bookmarks: number;
    crops: number;
    downloads: number;
    total: number;
    uniqueArticles: number;
  };
  days: ActivityDay[];
  recent: Array<{ type: ActivityType; articleId: string; date: string }>;
  topArticles: Array<{
    articleId: string;
    reads: number;
    bookmarks: number;
    crops: number;
    downloads: number;
    total: number;
    recordedSeconds: number;
    timedSessions: number;
    averageSessionSeconds: number;
    maxSessionSeconds: number;
    secondsPerPageEstimate: number;
  }>;
  firstActivityAt: string | null;
  lastActivityAt: string | null;
}

export async function getUserActivity(): Promise<UserActivity> {
  const { data } = await api.get<UserActivity>('/activity');
  return data;
}
