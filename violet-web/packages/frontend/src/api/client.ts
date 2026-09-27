import axios from 'axios';
import type { AxiosAdapter } from 'axios';

export const api = axios.create({
  baseURL: '/api',
  timeout: 30000,
});

// Apps inject their implementation before mounting React. The web defaults stay
// here, so the web build never imports a native runtime or the sibling app.
let imageUrl = (url: string, referer?: string) => {
  const params = new URLSearchParams({ url });
  if (referer) params.set('referer', referer);
  return `/api/proxy/image?${params.toString()}`;
};
let availableRoute = (_path: string) => true;

export function configurePlatform(platform: {
  adapter: AxiosAdapter;
  imageUrl: typeof imageUrl;
  availableRoute?: typeof availableRoute;
}) {
  api.defaults.adapter = platform.adapter;
  imageUrl = platform.imageUrl;
  availableRoute = platform.availableRoute ?? (() => true);
}

export function getPlatformImageUrl(url: string, referer?: string): string {
  return imageUrl(url, referer);
}

export function isRouteAvailable(path: string): boolean {
  return availableRoute(path);
}
