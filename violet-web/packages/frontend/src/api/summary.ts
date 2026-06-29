import { api } from './client';

export async function getArticleSummary(articleId: number): Promise<string | null> {
  try {
    const { data } = await api.get<{ articleId: string; content: string }>(
      `/summary/${articleId}`,
    );
    return data.content;
  } catch {
    return null;
  }
}
