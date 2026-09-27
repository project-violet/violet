type SetNativeFullscreen = (command: string, args: { enabled: boolean }) => Promise<boolean>;

// Serialize enter/exit, including React StrictMode's enter/exit/enter cycle.
// A delayed native exit must never override a newer viewer entry.
export function createViewerFullscreen(invoke: SetNativeFullscreen, doc: Document) {
  const viewport = doc.querySelector<HTMLMetaElement>('meta[name="viewport"]');
  const originalViewport = viewport?.content;
  let pending = Promise.resolve();
  return (enabled: boolean): Promise<void> => {
    const next = pending.then(async () => {
      const supported = await invoke('native_viewer_fullscreen', { enabled });
      if (supported && viewport && originalViewport !== undefined) {
        const base = originalViewport.replace(/,?\s*viewport-fit\s*=\s*[^,]+/g, '');
        viewport.content = enabled ? `${base}, viewport-fit=cover` : originalViewport;
      }
    });
    // A failed transition must not prevent a later exit or retry.
    pending = next.catch(() => {});
    return next;
  };
}
