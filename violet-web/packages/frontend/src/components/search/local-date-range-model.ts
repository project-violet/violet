import type { DateDistributionResponse } from '@violet-web/shared';

const DAY_MS = 86_400_000;

function normalizedDate(value: string): string | null {
  const match = value.match(/^(\d{4}-\d{2}-\d{2})/);
  if (!match) return null;
  const parsed = Date.parse(`${match[1]}T00:00:00Z`);
  return Number.isNaN(parsed) ? null : match[1];
}

function nextDay(value: string): string {
  return new Date(Date.parse(`${value}T00:00:00Z`) + DAY_MS).toISOString().slice(0, 10);
}

function nextMonth(value: string): string {
  const date = new Date(`${value.slice(0, 7)}-01T00:00:00Z`);
  date.setUTCMonth(date.getUTCMonth() + 1);
  return date.toISOString().slice(0, 10);
}

function nextYear(value: string): string {
  return `${Number(value.slice(0, 4)) + 1}-01-01`;
}

export function buildLocalDateDistribution(values: string[]): DateDistributionResponse {
  const dates = values.map(normalizedDate).filter((value): value is string => value !== null).sort();
  if (dates.length === 0) {
    return { minDate: null, maxDate: null, totalCount: 0, invalidCount: values.length, unit: 'day', buckets: [] };
  }

  const minDate = dates[0];
  const maxDate = dates[dates.length - 1];
  const spanDays = Math.round(
    (Date.parse(`${maxDate}T00:00:00Z`) - Date.parse(`${minDate}T00:00:00Z`)) / DAY_MS,
  ) + 1;
  const unit = spanDays <= 100 ? 'day' : spanDays <= 3100 ? 'month' : 'year';
  const bucketStart = unit === 'day'
    ? minDate
    : unit === 'month'
      ? `${minDate.slice(0, 7)}-01`
      : `${minDate.slice(0, 4)}-01-01`;
  const advance = unit === 'day' ? nextDay : unit === 'month' ? nextMonth : nextYear;
  const counts = new Map<string, number>();
  for (const date of dates) {
    const key = unit === 'day' ? date : unit === 'month' ? `${date.slice(0, 7)}-01` : `${date.slice(0, 4)}-01-01`;
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }

  const buckets = [];
  for (let start = bucketStart; start <= maxDate; start = advance(start)) {
    buckets.push({ start, end: advance(start), count: counts.get(start) ?? 0 });
  }
  return {
    minDate,
    maxDate,
    totalCount: dates.length,
    invalidCount: values.length - dates.length,
    unit,
    buckets,
  };
}

export function filterItemsByDateRange<T>(
  items: T[],
  getDate: (item: T) => string,
  from?: string,
  to?: string,
): T[] {
  if (!from && !to) return items;
  return items.filter((item) => {
    const date = normalizedDate(getDate(item));
    return date !== null && (!from || date >= from) && (!to || date <= to);
  });
}
