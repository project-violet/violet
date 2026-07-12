export function clampRange(
  from: number,
  to: number,
  min: number,
  max: number,
  active: 'from' | 'to',
): [number, number] {
  const nextFrom = Math.max(min, Math.min(max, from));
  const nextTo = Math.max(min, Math.min(max, to));
  if (nextFrom <= nextTo) return [nextFrom, nextTo];
  return active === 'from'
    ? [nextTo, nextTo]
    : [nextFrom, nextFrom];
}

const DAY_MS = 86_400_000;

function dateMs(value: string): number {
  return Date.parse(`${value}T00:00:00Z`);
}

export function buildSmoothAreaPath(values: number[], width: number, height: number): string {
  if (values.length === 0) return '';
  const max = Math.max(1, ...values);
  const points = values.map((value, index) => ({
    x: values.length === 1 ? width / 2 : (index / (values.length - 1)) * width,
    y: height - (value / max) * height,
  }));
  let path = `M 0 ${height} L ${points[0].x} ${points[0].y}`;
  for (let index = 1; index < points.length; index += 1) {
    const previous = points[index - 1];
    const current = points[index];
    const midpoint = (previous.x + current.x) / 2;
    path += ` C ${midpoint} ${previous.y}, ${midpoint} ${current.y}, ${current.x} ${current.y}`;
  }
  return `${path} L ${width} ${height} Z`;
}

export function dateToDayOffset(minDate: string, value: string): number {
  return Math.round((dateMs(value) - dateMs(minDate)) / DAY_MS);
}

export function dayOffsetToDate(minDate: string, offset: number): string {
  return new Date(dateMs(minDate) + offset * DAY_MS).toISOString().slice(0, 10);
}

export function estimateSelectedCount(
  buckets: Array<{ start: string; end: string; count: number }>,
  from: string,
  to: string,
  availableFrom?: string,
  availableTo?: string,
): number {
  const selectedStart = dateMs(from);
  const selectedEnd = dateMs(to) + DAY_MS;
  const availableStart = availableFrom ? dateMs(availableFrom) : Number.NEGATIVE_INFINITY;
  const availableEnd = availableTo ? dateMs(availableTo) + DAY_MS : Number.POSITIVE_INFINITY;
  const estimate = buckets.reduce((sum, bucket) => {
    const bucketStart = Math.max(dateMs(bucket.start), availableStart);
    const bucketEnd = Math.min(dateMs(bucket.end), availableEnd);
    const overlap = Math.max(
      0,
      Math.min(selectedEnd, bucketEnd) - Math.max(selectedStart, bucketStart),
    );
    if (overlap === 0) return sum;
    return sum + bucket.count * (overlap / Math.max(DAY_MS, bucketEnd - bucketStart));
  }, 0);
  return Math.round(estimate);
}

export function updateDateParams(
  current: URLSearchParams,
  from?: string,
  to?: string,
): URLSearchParams {
  const next = new URLSearchParams(current);
  if (from) next.set('from', from);
  else next.delete('from');
  if (to) next.set('to', to);
  else next.delete('to');
  next.delete('p');
  return next;
}
