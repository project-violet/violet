/** Coalesce checks started in the same turn while preserving per-ID query caches. */
export function createStatusBatcher(fetchBatch: (ids: string[]) => Promise<Record<string, boolean>>) {
  let pending: Array<{ id: string; resolve: (value: boolean) => void; reject: (error: unknown) => void }> = [];
  let scheduled = false;
  return (id: string): Promise<boolean> => new Promise((resolve, reject) => {
    pending.push({ id, resolve, reject });
    if (scheduled) return;
    scheduled = true;
    setTimeout(() => {
      const entries = pending;
      pending = [];
      scheduled = false;
      const ids = [...new Set(entries.map((entry) => entry.id))];
      for (let offset = 0; offset < ids.length; offset += 200) {
        const chunk = ids.slice(offset, offset + 200);
        const included = new Set(chunk);
        const callers = entries.filter((entry) => included.has(entry.id));
        void Promise.resolve().then(() => fetchBatch(chunk)).then(
          (values) => callers.forEach((entry) => entry.resolve(values[entry.id] === true)),
          (error: unknown) => callers.forEach((entry) => entry.reject(error)),
        );
      }
    }, 0);
  });
}
