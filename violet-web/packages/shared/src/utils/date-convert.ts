/**
 * .NET Ticks epoch: January 1, 0001 (Gregorian).
 * JS epoch: January 1, 1970.
 * Difference in ticks (1 tick = 100 nanoseconds = 0.0001 ms).
 */
const TICKS_EPOCH_OFFSET = 621355968000000000n;
const TICKS_PER_MS = 10000n;

/**
 * Convert .NET DateTime Ticks to JavaScript Date.
 */
export function ticksToDate(ticks: number | bigint): Date {
  const t = typeof ticks === 'bigint' ? ticks : BigInt(ticks);
  const ms = Number((t - TICKS_EPOCH_OFFSET) / TICKS_PER_MS);
  return new Date(ms);
}

/**
 * Convert JavaScript Date to .NET DateTime Ticks.
 */
export function dateToTicks(date: Date): bigint {
  return BigInt(date.getTime()) * TICKS_PER_MS + TICKS_EPOCH_OFFSET;
}
