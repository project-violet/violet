import type {
  BookmarkGroup,
  BookmarkArticle,
  BookmarkArtist,
  BookmarkCropImage,
  AddBookmarkArticleRequest,
  AddBookmarkArtistRequest,
  AddBookmarkCropImageRequest,
  CreateBookmarkGroupRequest,
} from '@violet-web/shared';
import { api } from './client';

// Groups
export async function getGroups(): Promise<BookmarkGroup[]> {
  const { data } = await api.get<BookmarkGroup[]>('/bookmarks/groups');
  return data;
}

export async function createGroup(req: CreateBookmarkGroupRequest): Promise<{ Id: number }> {
  const { data } = await api.post<{ Id: number }>('/bookmarks/groups', req);
  return data;
}

export async function deleteGroup(id: number): Promise<void> {
  await api.delete(`/bookmarks/groups/${id}`);
}

// Articles
export async function getBookmarkArticles(groupId?: number): Promise<BookmarkArticle[]> {
  const { data } = await api.get<BookmarkArticle[]>('/bookmarks/articles', {
    params: groupId !== undefined ? { groupId } : {},
  });
  return data;
}

export async function addBookmarkArticle(req: AddBookmarkArticleRequest): Promise<{ Id: number }> {
  const { data } = await api.post<{ Id: number }>('/bookmarks/articles', req);
  return data;
}

export async function deleteBookmarkArticle(id: number): Promise<void> {
  await api.delete(`/bookmarks/articles/${id}`);
}

export async function checkBookmark(articleId: string): Promise<boolean> {
  const { data } = await api.get<{ bookmarked: boolean }>(
    `/bookmarks/articles/check/${articleId}`,
  );
  return data.bookmarked;
}

// Artists
export async function getBookmarkArtists(groupId?: number): Promise<BookmarkArtist[]> {
  const { data } = await api.get<BookmarkArtist[]>('/bookmarks/artists', {
    params: groupId !== undefined ? { groupId } : {},
  });
  return data;
}

export async function addBookmarkArtist(req: AddBookmarkArtistRequest): Promise<{ Id: number }> {
  const { data } = await api.post<{ Id: number }>('/bookmarks/artists', req);
  return data;
}

export async function deleteBookmarkArtist(id: number): Promise<void> {
  await api.delete(`/bookmarks/artists/${id}`);
}

// Crop Images
export async function getCropBookmarks(): Promise<BookmarkCropImage[]> {
  const { data } = await api.get<BookmarkCropImage[]>('/bookmarks/crops');
  return data;
}

export async function addCropBookmark(req: AddBookmarkCropImageRequest): Promise<{ Id: number }> {
  const { data } = await api.post<{ Id: number }>('/bookmarks/crops', req);
  return data;
}

export async function deleteCropBookmark(id: number): Promise<void> {
  await api.delete(`/bookmarks/crops/${id}`);
}
