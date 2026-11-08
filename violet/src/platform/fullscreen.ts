type SetNativeFullscreen = (command: string, args: { enabled: boolean; dark: boolean }) => Promise<boolean>;

// Serialize enter/exit, including React StrictMode's enter/exit/enter cycle.
// A delayed native exit must never override a newer viewer entry.
export function createViewerFullscreen(invoke: SetNativeFullscreen, doc: Document) {
  const viewport = doc.querySelector<HTMLMetaElement>('meta[name="viewport"]');
  const originalViewport = viewport?.content;
  let viewportConfigured = false;
  let requestedFullscreen = false;
  let pending = Promise.resolve();
  const setFullscreen = (enabled: boolean): Promise<void> => {
    requestedFullscreen = enabled;
    const next = pending.then(async () => {
      const dark = doc.documentElement.dataset.theme !== 'light';
      const supported = await invoke('native_viewer_fullscreen', { enabled, dark });
      if (supported && !viewportConfigured) {
        // Keep one viewport/inset policy for the entire iOS app. Changing it
        // after UIKit updates the status bar leaves WKWebView with stale insets.
        if (viewport && originalViewport !== undefined) {
          const base = originalViewport.replace(/,?\s*viewport-fit\s*=\s*[^,]+/g, '');
          viewport.content = `${base}, viewport-fit=cover`;
        }
        doc.documentElement.dataset.nativeIos = 'true';
        viewportConfigured = true;
        // ThemeProvider also handles system theme changes. Observe its resolved
        // theme so UIKit's status bar updates without requiring a reader visit.
        const Observer = doc.defaultView?.MutationObserver;
        if (Observer) {
          new Observer(() => { void setFullscreen(requestedFullscreen).catch(console.error); })
            .observe(doc.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
        }
      }
    });
    // A failed transition must not prevent a later exit or retry.
    pending = next.catch(() => {});
    return next;
  };
  return setFullscreen;
}
