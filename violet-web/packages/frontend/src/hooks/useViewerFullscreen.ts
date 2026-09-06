import { useEffect } from 'react';
import { useViewerStore } from '../stores/viewer-store';
import { useMediaQuery } from './useMediaQuery';

export function useViewerFullscreen() {
  const enabled = useViewerStore((state) => state.mobileFullscreenEnabled);
  const mobile = useMediaQuery('(hover: none) and (pointer: coarse)');

  const installedApp = useMediaQuery('(display-mode: standalone), (display-mode: fullscreen), (display-mode: minimal-ui)');

  useEffect(() => {
    if (installedApp || !enabled || !mobile || !document.fullscreenEnabled || document.fullscreenElement) return;
    let disposed = false;
    let pending = false;
    let entered = false;
    const element = document.documentElement;
    const removeListeners = () => {
      document.removeEventListener('click', request, true);
      document.removeEventListener('touchend', request, true);
    };
    function request() {
      if (disposed || pending || entered || document.fullscreenElement) return;
      // A direct URL load has no activation. Wait for a touch/click instead.
      if (!navigator.userActivation?.isActive) return;
      pending = true;
      element.requestFullscreen({ navigationUI: 'hide' }).then(() => {
        entered = true;
        removeListeners();
        if (disposed && document.fullscreenElement === element) {
          void document.exitFullscreen().catch(() => {});
        }
      }).catch(() => {
        // Unsupported/blocked requests must not interrupt reading.
      }).finally(() => { pending = false; });
    }
    document.addEventListener('click', request, true);
    document.addEventListener('touchend', request, true);
    request();
    return () => {
      disposed = true;
      removeListeners();
      if (entered && document.fullscreenElement === element) {
        void document.exitFullscreen().catch(() => {});
      }
    };
  }, [enabled, mobile, installedApp]);
}
