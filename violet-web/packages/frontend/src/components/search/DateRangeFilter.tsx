import { useEffect, useMemo, useRef, useState } from 'react';
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

export function DateRangeFilter({
  query,
  from,
  to,
  compact = false,
  distributionData,
  distributionLoading = false,
  onCommit,
}: DateRangeFilterProps) {
  const distribution = useDateDistribution(query, distributionData === undefined);
  const data = distributionData ?? distribution.data;
  const isLoading = distributionData === undefined ? distribution.isLoading : distributionLoading;
  const buckets = data?.buckets ?? [];
  const minDate = data?.minDate ?? '';
  const maxDate = data?.maxDate ?? '';
  const maxOffset = useMemo(
    () => minDate && maxDate ? dateToDayOffset(minDate, maxDate) : 0,
    [maxDate, minDate],
  );
  const [draft, setDraft] = useState<[number, number]>([0, 0]);
  const draftRef = useRef<[number, number]>([0, 0]);

  useEffect(() => {
    if (!minDate || !maxDate) return;
    const next = clampRange(
      dateToDayOffset(minDate, from ?? minDate),
      dateToDayOffset(minDate, to ?? maxDate),
      0,
      maxOffset,
      'from',
    );
    draftRef.current = next;
    setDraft(next);
  }, [from, maxDate, maxOffset, minDate, to]);

  if (isLoading) {
    return (
      <div
        className={`${styles.skeleton} ${compact ? styles.compactSkeleton : ''}`}
        aria-label="날짜 분포 불러오는 중"
      />
    );
  }

  if (distributionData === undefined && distribution.isError) {
    return (
      <div className={styles.error}>
        <span>날짜 분포를 불러오지 못했습니다.</span>
        <button type="button" onClick={() => distribution.refetch()}>다시 시도</button>
      </div>
    );
  }

  if (!data || buckets.length === 0) return null;

  const fromDate = dayOffsetToDate(minDate, draft[0]);
  const toDate = dayOffsetToDate(minDate, draft[1]);
  const selectedCount = estimateSelectedCount(
    buckets,
    fromDate,
    toDate,
    minDate,
    maxDate,
  );
  const chartWidth = 1000;
  const chartHeight = compact ? 26 : 66;
  const areaPath = buildSmoothAreaPath(buckets.map((bucket) => bucket.count), chartWidth, chartHeight);
  const selectionStart = maxOffset > 0 ? (draft[0] / maxOffset) * 100 : 0;
  const selectionEnd = maxOffset > 0 ? (draft[1] / maxOffset) * 100 : 100;

  const commit = () => {
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
      aria-label="작품 날짜 범위"
      onDoubleClick={() => onCommit(undefined, undefined)}
    >
      <header className={styles.header}>
        <span>{fromDate} – {toDate}</span>
        <span>{selectedCount.toLocaleString()}개 작품</span>
        <button type="button" onClick={() => onCommit(undefined, undefined)}>초기화</button>
      </header>
      <div className={styles.histogram} aria-hidden="true">
        <svg viewBox={`0 0 ${chartWidth} ${chartHeight}`} preserveAspectRatio="none">
          <defs>
            <linearGradient id="date-area-gradient" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stopColor="var(--color-primary)" stopOpacity="0.9" />
              <stop offset="1" stopColor="var(--color-primary)" stopOpacity="0.16" />
            </linearGradient>
          </defs>
          <path className={styles.areaInactive} d={areaPath} />
          <path
            className={styles.areaActive}
            d={areaPath}
            style={{ clipPath: `inset(0 ${100 - selectionEnd}% 0 ${selectionStart}%)` }}
          />
        </svg>
      </div>
      <div className={styles.rangeWrap}>
        <input
          aria-label="시작 날짜"
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
          aria-label="종료 날짜"
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
