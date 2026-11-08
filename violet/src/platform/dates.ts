import type { DateDistributionResponse } from '@violet-web/shared';

export function dateDistribution(days: { start: string | null; count: number }[]): DateDistributionResponse {
  const valid = days.filter((row): row is { start: string; count: number } => row.start !== null);
  const minDate = valid[0]?.start ?? null;
  const maxDate = valid.at(-1)?.start ?? null;
  const span = minDate && maxDate ? (Date.parse(maxDate) - Date.parse(minDate)) / 86_400_000 : 0;
  const unit = !minDate || span > 1860 ? 'year' : span > 45 ? 'month' : 'day';
  const floor = (day: string) => unit === 'year' ? `${day.slice(0, 4)}-01-01` : unit === 'month' ? `${day.slice(0, 7)}-01` : day;
  const counts = new Map<string, number>();
  for (const row of valid) counts.set(floor(row.start), (counts.get(floor(row.start)) ?? 0) + row.count);
  const buckets: DateDistributionResponse['buckets'] = [];
  if (minDate && maxDate) {
    let cursor = new Date(`${floor(minDate)}T00:00:00Z`);
    const last = new Date(`${floor(maxDate)}T00:00:00Z`);
    while (cursor <= last) {
      const start = cursor.toISOString().slice(0, 10);
      const end = new Date(cursor);
      if (unit === 'year') end.setUTCFullYear(end.getUTCFullYear() + 1);
      else if (unit === 'month') end.setUTCMonth(end.getUTCMonth() + 1);
      else end.setUTCDate(end.getUTCDate() + 1);
      buckets.push({ start, end: end.toISOString().slice(0, 10), count: counts.get(start) ?? 0 });
      cursor = end;
    }
  }
  return { minDate, maxDate, unit, buckets, totalCount: valid.reduce((n, row) => n + row.count, 0), invalidCount: days.find(row => row.start === null)?.count ?? 0 };
}
