import type Database from 'better-sqlite3';
import type {
  DateDistributionBucket,
  DateDistributionResponse,
} from '@violet-web/shared';

const DOTNET_UNIX_EPOCH_TICKS = 621355968000000000;
const CACHE_TTL_MS = 60_000;
const CACHE_MAX_ENTRIES = 100;

const distributionCache = new Map<
  string,
  { value: DateDistributionResponse; expiresAt: number }
>();

export function normalizedPublishedSql(column = 'Published'): string {
  return `CASE
    WHEN typeof(${column})='integer' AND ${column}>${DOTNET_UNIX_EPOCH_TICKS}
      THEN datetime((${column}-${DOTNET_UNIX_EPOCH_TICKS})/10000000.0, 'unixepoch')
    WHEN typeof(${column})='text' THEN datetime(${column})
    ELSE NULL END`;
}

export function parseDateBounds(from?: string, to?: string): {
  from?: string;
  toExclusive?: string;
} {
  const isoDay = /^\d{4}-\d{2}-\d{2}$/;
  if ((from && !isoDay.test(from)) || (to && !isoDay.test(to))) {
    throw new Error('Date bounds must use YYYY-MM-DD');
  }
  for (const value of [from, to]) {
    if (!value) continue;
    const parsed = new Date(`${value}T00:00:00Z`);
    if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value) {
      throw new Error('Date bounds must use valid calendar dates');
    }
  }
  if (from && to && from > to) {
    throw new Error('from must be before or equal to to');
  }

  let toExclusive: string | undefined;
  if (to) {
    const nextDay = new Date(`${to}T00:00:00Z`);
    nextDay.setUTCDate(nextDay.getUTCDate() + 1);
    toExclusive = `${nextDay.toISOString().slice(0, 10)} 00:00:00`;
  }

  return {
    from: from ? `${from} 00:00:00` : undefined,
    toExclusive,
  };
}

function daysBetween(from: string, to: string): number {
  return Math.ceil(
    (Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) /
      86_400_000,
  );
}

function selectBucketUnit(
  minDate: string,
  maxDate: string,
): DateDistributionResponse['unit'] {
  const days = daysBetween(minDate, maxDate);
  if (days > 1_860) return 'year';
  if (days > 45) return 'month';
  return 'day';
}

function bucketStartExpression(unit: DateDistributionResponse['unit']): string {
  if (unit === 'year') return "strftime('%Y-01-01', publishedAt)";
  if (unit === 'month') return "strftime('%Y-%m-01', publishedAt)";
  return 'date(publishedAt)';
}

function addBucket(date: Date, unit: DateDistributionResponse['unit']): void {
  if (unit === 'year') date.setUTCFullYear(date.getUTCFullYear() + 1);
  else if (unit === 'month') date.setUTCMonth(date.getUTCMonth() + 1);
  else date.setUTCDate(date.getUTCDate() + 1);
}

function floorDate(value: string, unit: DateDistributionResponse['unit']): Date {
  const date = new Date(`${value}T00:00:00Z`);
  if (unit === 'year') {
    date.setUTCMonth(0, 1);
  } else if (unit === 'month') {
    date.setUTCDate(1);
  }
  return date;
}

function formatDay(date: Date): string {
  return date.toISOString().slice(0, 10);
}

export function getDateDistribution(
  db: Database.Database,
  condition: string,
  cacheKey: string,
): DateDistributionResponse {
  const now = Date.now();
  const cached = distributionCache.get(cacheKey);
  if (cached && cached.expiresAt > now) return cached.value;
  if (cached) distributionCache.delete(cacheKey);

  const published = normalizedPublishedSql('Published');
  const baseCte = `WITH matched AS (
    SELECT ${published} AS publishedAt
    FROM HitomiColumnModel
    WHERE ${condition}
  )`;
  const summary = db.prepare(`${baseCte}
    SELECT MIN(publishedAt) AS minDate,
           MAX(publishedAt) AS maxDate,
           SUM(publishedAt IS NOT NULL) AS totalCount,
           SUM(publishedAt IS NULL) AS invalidCount
    FROM matched`).get() as {
      minDate: string | null;
      maxDate: string | null;
      totalCount: number | null;
      invalidCount: number | null;
    };

  const minDate = summary.minDate?.slice(0, 10) ?? null;
  const maxDate = summary.maxDate?.slice(0, 10) ?? null;
  const unit = minDate && maxDate ? selectBucketUnit(minDate, maxDate) : 'year';
  const buckets: DateDistributionBucket[] = [];

  if (minDate && maxDate) {
    const grouped = db.prepare(`${baseCte}
      SELECT ${bucketStartExpression(unit)} AS start, COUNT(*) AS count
      FROM matched
      WHERE publishedAt IS NOT NULL
      GROUP BY start
      ORDER BY start`).all() as Array<{ start: string; count: number }>;
    const counts = new Map(grouped.map((row) => [row.start, row.count]));
    const cursor = floorDate(minDate, unit);
    const last = floorDate(maxDate, unit);
    while (cursor <= last) {
      const start = formatDay(cursor);
      const endCursor = new Date(cursor);
      addBucket(endCursor, unit);
      buckets.push({ start, end: formatDay(endCursor), count: counts.get(start) ?? 0 });
      addBucket(cursor, unit);
    }
  }

  const value: DateDistributionResponse = {
    minDate,
    maxDate,
    totalCount: summary.totalCount ?? 0,
    invalidCount: summary.invalidCount ?? 0,
    unit,
    buckets,
  };

  if (distributionCache.size >= CACHE_MAX_ENTRIES) {
    const oldestKey = distributionCache.keys().next().value as string | undefined;
    if (oldestKey) distributionCache.delete(oldestKey);
  }
  distributionCache.set(cacheKey, { value, expiresAt: now + CACHE_TTL_MS });
  return value;
}
