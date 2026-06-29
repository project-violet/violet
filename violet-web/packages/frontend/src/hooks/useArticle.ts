import { useQuery } from '@tanstack/react-query';
import { getArticle } from '../api/content';

export function useArticle(id: number) {
  return useQuery({
    queryKey: ['article', id],
    queryFn: () => getArticle(id),
    enabled: id > 0,
  });
}
