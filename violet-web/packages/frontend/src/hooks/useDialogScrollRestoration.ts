import { useLayoutEffect, type RefObject } from 'react';
import { useLocation } from 'react-router';

/** Each browser history entry owns its dialog scroll position. */
export function useDialogScrollRestoration(ref: RefObject<HTMLDivElement | null>) {
  const { key } = useLocation();
  useLayoutEffect(() => {
    const element = ref.current;
    if (!element) return;
    const storageKey = `messageDialogScroll:${key}`;
    const target = Number(sessionStorage.getItem(storageKey)) || 0;
    let restoring = target > 0;
    const restore = () => {
      if (restoring) element.scrollTop = target;
    };
    const save = () => {
      if (!restoring) sessionStorage.setItem(storageKey, String(element.scrollTop));
    };
    const stopRestoring = () => { restoring = false; save(); };
    element.scrollTop = target;
    // Observe children: the viewport stays fixed while results and images grow.
    const observer = new ResizeObserver(restore);
    const observeChildren = () => {
      for (const child of element.children) observer.observe(child);
      restore();
    };
    const mutations = new MutationObserver(observeChildren);
    mutations.observe(element, { childList: true, subtree: true });
    observeChildren();
    element.addEventListener('scroll', save, { passive: true });
    element.addEventListener('wheel', stopRestoring, { passive: true });
    element.addEventListener('touchstart', stopRestoring, { passive: true });
    element.addEventListener('pointerdown', stopRestoring);
    element.addEventListener('keydown', stopRestoring);
    return () => {
      save();
      observer.disconnect();
      mutations.disconnect();
      element.removeEventListener('scroll', save);
      element.removeEventListener('wheel', stopRestoring);
      element.removeEventListener('touchstart', stopRestoring);
      element.removeEventListener('pointerdown', stopRestoring);
      element.removeEventListener('keydown', stopRestoring);
    };
  }, [key, ref]);
}
