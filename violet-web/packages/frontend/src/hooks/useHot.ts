import { useQuery } from '@tanstack/react-query';
import { fetchHotView, type HotPeriod } from '../api/hot';
import { getArticlesBatch } from '../api/content';
import { useAppStore } from '../stores/app-store';
import type { Article } from '@violet-web/shared';

const PAGE_SIZE = 50;

export interface RankInfo {
  rank: number;
  viewCount: number;
}

export function useHot(period: HotPeriod, page: number) {
  const { developerMode, hmacSalt, serverHost } = useAppStore();

  const enabled = developerMode && hmacSalt.trim().length > 0;

  const {
    data: hotData,
    isLoading: hotLoading,
    error: hotError,
  } = useQuery({
    queryKey: ['hot', 'view', serverHost, hmacSalt, period, page],
    queryFn: () =>
      fetchHotView(serverHost, hmacSalt, period, page * PAGE_SIZE, PAGE_SIZE),
    enabled,
    staleTime: 5 * 60 * 1000,
  });

  const elements = hotData?.elements ?? [];
  const articleIds = elements.map((e) => e.articleId);

  const {
    data: articles,
    isLoading: articlesLoading,
    error: articlesError,
  } = useQuery({
    queryKey: ['hot', 'articles', articleIds],
    queryFn: () => getArticlesBatch(articleIds),
    enabled: articleIds.length > 0,
  });

  // Re-sort to preserve view-count ranking order
  const orderedArticles: Article[] = [];
  const rankInfo = new Map<number, RankInfo>();

  if (articles && elements.length > 0) {
    const articleMap = new Map(articles.map((a) => [a.Id, a]));
    elements.forEach((el, i) => {
      const article = articleMap.get(el.articleId);
      if (article) {
        orderedArticles.push(article);
        rankInfo.set(el.articleId, {
          rank: page * PAGE_SIZE + i + 1,
          viewCount: el.count,
        });
      }
    });
  }

  return {
    articles: orderedArticles,
    rankInfo,
    isLoading: hotLoading || articlesLoading,
    error: hotError || articlesError,
    enabled,
    hasMore: elements.length === PAGE_SIZE,
  };
}
