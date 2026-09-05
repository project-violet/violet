import { useTranslation } from 'react-i18next';
import { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { useDateDistribution } from '../../hooks/useDateDistribution';
import type { DateDistributionResponse } from '@violet-web/shared';
import {
  buildSmoothAreaPath,
  clampRange,
  dateToDayOffset,
  dayOffsetToDate,
  estimateSelectedCount,
} from './date-range-model';
import styles from './DateRangeFilter.module.css';

interface DateRangeFilterProps {
  query: string;
  from?: string;
  to?: string;
  compact?: boolean;
  distributionData?: DateDistributionResponse;
  distributionLoading?: boolean;
  onCommit: (from?: string, to?: string) => void;
}

const EMPTY_BUCKETS: DateDistributionResponse['buckets'] = [];

export function DateRangeFilter({
  query,
  from,
  to,
  compact = false,
  distributionData,
  distributionLoading = false,
  onCommit,
}: DateRangeFilterProps) {
  const { t } = useTranslation();
  const distribution = useDateDistribution(query, distributionData === undefined);
  const incoming = distributionData ?? distribution.data;
  const [previousData, setPreviousData] = useState<DateDistributionResponse>();
  const hasIncoming = !!(incoming?.minDate && incoming.maxDate && incoming.buckets.length);
  const isRemote = distributionData === undefined;
  const isLoading = isRemote
    ? distribution.isLoading || distribution.isFetching || distribution.isQueryChanging
    : distributionLoading;
  const isError = isRemote && distribution.isError;
  const isPendingReplacement = isRemote
    ? distribution.isQueryChanging || distribution.isPlaceholderData || (!incoming && distribution.isFetching)
    : distributionLoading;
  useEffect(() => {
    if (hasIncoming && !isPendingReplacement) setPreviousData(incoming);
  }, [hasIncoming, incoming, isPendingReplacement]);
  // Keep the entire previous view until the replacement distribution is ready.
  const data = hasIncoming && !isPendingReplacement ? incoming : previousData;
  const canAdjust = hasIncoming && !isError && !(isRemote
    ? distribution.isPlaceholderData || distribution.isQueryChanging
    : distributionLoading);
  const buckets = data?.buckets ?? EMPTY_BUCKETS;
  const minDate = data?.minDate ?? '';
  const maxDate = data?.maxDate ?? '';
  const maxOffset = useMemo(
    () => minDate && maxDate ? dateToDayOffset(minDate, maxDate) : 0,
    [maxDate, minDate],
  );
  const chartWidth = 1000;
  const chartHeight = compact ? 26 : 66;
  const areaPath = useMemo(
    () => buildSmoothAreaPath(buckets.map((bucket) => bucket.count), chartWidth, chartHeight),
    [buckets, chartHeight],
  );
  const [draft, setDraft] = useState<[number, number]>([0, 0]);
  const draftRef = useRef<[number, number]>([0, 0]);

  useLayoutEffect(() => {
    if (!minDate || !maxDate || isPendingReplacement) return;
    const next = clampRange(
      dateToDayOffset(minDate, from ?? minDate),
      dateToDayOffset(minDate, to ?? maxDate),
      0,
      maxOffset,
      'from',
    );
    draftRef.current = next;
    setDraft(next);
  }, [from, maxDate, maxOffset, minDate, to, isPendingReplacement]);

  const fromDate = minDate ? dayOffsetToDate(minDate, draft[0]) : (from ?? '—');
  const toDate = minDate ? dayOffsetToDate(minDate, draft[1]) : (to ?? '—');
  const selectedCount = hasIncoming || (isPendingReplacement && !!data) ? estimateSelectedCount(
    buckets,
    fromDate,
    toDate,
    minDate,
    maxDate,
  ) : 0;
  const selectionStart = maxOffset > 0 ? (draft[0] / maxOffset) * 100 : 0;
  const selectionEnd = maxOffset > 0 ? (draft[1] / maxOffset) * 100 : 100;

  const commit = () => {
    if (!canAdjust) return;
    const [currentFrom, currentTo] = draftRef.current;
    const nextFrom = currentFrom === 0
      ? undefined
      : dayOffsetToDate(minDate, currentFrom);
    const nextTo = currentTo === maxOffset
      ? undefined
      : dayOffsetToDate(minDate, currentTo);
    if (nextFrom !== from || nextTo !== to) onCommit(nextFrom, nextTo);
  };

  const updateThumb = (active: 'from' | 'to', value: number) => {
    const current = draftRef.current;
    const next = clampRange(
      active === 'from' ? value : current[0],
      active === 'to' ? value : current[1],
      0,
      maxOffset,
      active,
    );
    draftRef.current = next;
    setDraft(next);
  };

  return (
    <section
      className={`${styles.container} ${compact ? styles.compact : ''}`}
      aria-label={t('dateRange.label')}
      aria-busy={isLoading}
      onDoubleClick={() => onCommit(undefined, undefined)}
    >
      <header className={styles.header}>
        <span>{fromDate} – {toDate}</span>
        <span role="status">{isError ? t('dateRange.error') : isLoading && !data
          ? t('dateRange.loading') : t('dateRange.count', { count: selectedCount, formattedCount: selectedCount.toLocaleString() })}</span>
        {isError && <button type="button" onClick={() => distribution.refetch()}>{t('dateRange.retry')}</button>}
        <button type="button" onClick={() => onCommit(undefined, undefined)}>{t('dateRange.reset')}</button>
      </header>
      <div className={styles.histogram} aria-hidden="true">
        <svg viewBox={`0 0 ${chartWidth} ${chartHeight}`} preserveAspectRatio="none">
          <defs>
            <linearGradient id="date-area-gradient" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stopColor="var(--color-primary)" stopOpacity="0.9" />
              <stop offset="1" stopColor="var(--color-primary)" stopOpacity="0.16" />
            </linearGradient>
          </defs>
          <path className={styles.areaInactive} d={hasIncoming || isLoading || isError ? areaPath : ''} />
          <path
            className={styles.areaActive}
            d={hasIncoming || isLoading || isError ? areaPath : ''}
            style={{ clipPath: `inset(0 ${100 - selectionEnd}% 0 ${selectionStart}%)` }}
          />
        </svg>
      </div>
      <div className={styles.rangeWrap}>
        <input
          aria-label={t('dateRange.from')}
          disabled={!canAdjust}
          type="range"
          min={0}
          max={maxOffset}
          step={1}
          value={draft[0]}
          onChange={(event) => updateThumb('from', Number(event.target.value))}
          onPointerUp={commit}
          onKeyUp={commit}
          onBlur={commit}
        />
        <input
          aria-label={t('dateRange.to')}
          disabled={!canAdjust}
          type="range"
          min={0}
          max={maxOffset}
          step={1}
          value={draft[1]}
          onChange={(event) => updateThumb('to', Number(event.target.value))}
          onPointerUp={commit}
          onKeyUp={commit}
          onBlur={commit}
        />
      </div>
    </section>
  );
}
