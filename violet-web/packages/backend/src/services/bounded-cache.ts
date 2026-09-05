/** Keeps existing timestamp-based freshness checks, but bounds retained memory. */
export class BoundedCache<T extends { ts: number }> extends Map<string, T> {
  constructor(private readonly maxEntries = 200, private readonly ttl = 60_000) { super(); }
  override set(key: string, value: T): this {
    const cutoff = Date.now() - this.ttl;
    for (const [entryKey, entry] of this) {
      if (entry.ts <= cutoff) this.delete(entryKey);
    }
    this.delete(key);
    while (this.size >= this.maxEntries) this.delete(this.keys().next().value!);
    return super.set(key, value);
  }
}
