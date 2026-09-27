import { StrictMode, useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { convertFileSrc, invoke } from '@tauri-apps/api/core';
import { openUrl } from '@tauri-apps/plugin-opener';
import { App } from '../../violet-web/packages/frontend/src/App';
import { ThemeProvider } from '../../violet-web/packages/frontend/src/components/ThemeProvider';
import { configurePlatform } from '../../violet-web/packages/frontend/src/api/client';
import { NativeSetup, type Status } from './NativeSetup';
import { createAdapter } from './platform/adapter';
import { createBackend } from './platform/backend';
import { createViewerFullscreen } from './platform/fullscreen';
import { t } from './i18n';
import '../../violet-web/packages/frontend/src/styles/globals.css';

const mediaUrl = (params: Record<string, string>) => `${convertFileSrc('image', 'violet-media')}?${new URLSearchParams(params)}`;
const availableRoutes = new Set(['/', '/bookmarks', '/crop-bookmarks', '/history', '/downloads', '/message-search', '/settings']);
const viewerFullscreen = createViewerFullscreen(invoke, document);
configurePlatform({
  adapter: createAdapter(createBackend(invoke, mediaUrl)),
  imageUrl: (url, referer) => url.startsWith('violet-media:') || url.startsWith('http://violet-media.localhost')
    ? url : mediaUrl({ url, ...(referer ? { referer } : {}) }),
  availableRoute: path => availableRoutes.has(path),
  browserFullscreen: false,
  viewerFullscreen,
});

// Keep the shared SPA's BrowserRouter and URL state semantics. External links
// open in the OS browser, and shared "new tab" actions navigate this app window.
function openLink(raw: string) {
  const url = new URL(raw, location.href);
  if (url.origin === location.origin && raw.startsWith('/')) {
    history.pushState({}, '', `${url.pathname}${url.search}${url.hash}`);
    dispatchEvent(new PopStateEvent('popstate'));
  } else if (url.protocol === 'https:' || url.protocol === 'http:') {
    void openUrl(url.href).catch(console.error);
  }
}
window.open = (url) => { if (url) openLink(String(url)); return null; };
document.addEventListener('click', event => {
  const anchor = (event.target as Element).closest?.('a[target="_blank"]');
  if (anchor instanceof HTMLAnchorElement) { event.preventDefault(); openLink(anchor.getAttribute('href') ?? ''); }
});

function NativeRoot() {
  const [ready, setReady] = useState<boolean>();
  const [error, setError] = useState('');
  useEffect(() => {
    // Establish the iOS edge-to-edge viewport before rendering the first route,
    // including setup. Subsequent reader transitions only change system chrome.
    Promise.all([viewerFullscreen(false), invoke<Status>('native_status')])
      .then(([, status]) => setReady(status.dbExists)).catch(e => setError(String(e)));
  }, []);
  if (error) return <main className="native-setup"><section className="native-card" role="alert"><h1>{t('startupError')}</h1><pre>{error}</pre><button onClick={() => location.reload()}>{t('retry')}</button></section></main>;
  if (ready === undefined) return null;
  return ready ? <App /> : <><ThemeProvider /><NativeSetup onReady={() => setReady(true)} /></>;
}

createRoot(document.getElementById('root')!).render(<StrictMode><NativeRoot /></StrictMode>);
