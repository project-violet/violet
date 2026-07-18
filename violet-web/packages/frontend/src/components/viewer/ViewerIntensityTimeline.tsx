import { useId, useMemo, type PointerEvent as ReactPointerEvent } from 'react';
import { useTranslation } from 'react-i18next';
import type { IntensityTimeline } from '@violet-web/shared';
import styles from './ViewerIntensityTimeline.module.css';

interface ViewerIntensityTimelineProps {
  timeline: IntensityTimeline;
  currentPage: number;
  totalPages: number;
  onPageChange: (page: number) => void;
}

const WIDTH = 1000;
const HEIGHT = 76;
const TOP = 7;
const BOTTOM = 69;
const LEFT = 0;
const RIGHT = WIDTH;

function xForIndex(index: number, length: number): number {
  return length <= 1 ? WIDTH / 2 : LEFT + (index / (length - 1)) * (RIGHT - LEFT);
}

function yForScore(score: number): number {
  const clamped = Math.max(0, Math.min(100, score));
  return TOP + (1 - clamped / 100) * (BOTTOM - TOP);
}

function pathFor(values: number[]): string {
  return values
    .map((value, index) => {
      const command = index === 0 ? 'M' : 'L';
      return `${command}${xForIndex(index, values.length).toFixed(2)},${yForScore(value).toFixed(2)}`;
    })
    .join(' ');
}

export function ViewerIntensityTimeline({
  timeline,
  currentPage,
  totalPages,
  onPageChange,
}: ViewerIntensityTimelineProps) {
  const { t } = useTranslation();
  const gradientId = `viewer-intensity-${useId().replace(/:/g, '')}`;
  const smoothPath = useMemo(() => pathFor(timeline.smooth), [timeline.smooth]);

  if (timeline.smooth.length === 0) return null;

  const currentIndex = totalPages <= 1
    ? 0
    : Math.round((currentPage / (totalPages - 1)) * (timeline.smooth.length - 1));
  const currentScore = timeline.smooth[Math.max(0, Math.min(currentIndex, timeline.smooth.length - 1))];
  const currentX = xForIndex(currentIndex, timeline.smooth.length);
  const currentY = yForScore(currentScore);
  const areaPath = `${smoothPath} L${RIGHT},${BOTTOM} L${LEFT},${BOTTOM} Z`;

  const scrubToPointer = (event: ReactPointerEvent<SVGSVGElement>) => {
    if (event.buttons === 0) return;

    event.stopPropagation();
    const bounds = event.currentTarget.getBoundingClientRect();
    const ratio = Math.max(0, Math.min(1, (event.clientX - bounds.left) / bounds.width));
    const page = Math.round(ratio * Math.max(0, totalPages - 1));
    if (page !== currentPage) onPageChange(page);
  };

  return (
    <div className={styles.timeline}>
      <div className={styles.chartFrame}>
        <svg
          className={styles.chart}
          viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
          preserveAspectRatio="none"
          role="img"
          aria-label={t('viewer.intensity.ariaLabel', {
            page: currentPage + 1,
            score: Math.round(currentScore),
          })}
          onPointerDown={(event) => {
            event.currentTarget.setPointerCapture(event.pointerId);
            scrubToPointer(event);
          }}
          onPointerMove={scrubToPointer}
          onPointerUp={(event) => event.currentTarget.releasePointerCapture(event.pointerId)}
          onPointerCancel={(event) => event.currentTarget.releasePointerCapture(event.pointerId)}
          onClick={(event) => event.stopPropagation()}
        >
          <defs>
            <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="var(--color-primary)" stopOpacity="0.42" />
              <stop offset="100%" stopColor="var(--color-primary)" stopOpacity="0.03" />
            </linearGradient>
          </defs>
          <line className={styles.guide} x1="0" y1={yForScore(50)} x2={WIDTH} y2={yForScore(50)} />
          <path className={styles.area} d={areaPath} fill={`url(#${gradientId})`} />
          <path className={styles.smooth} d={smoothPath} />
          {timeline.peaks.map(([page, score]) => (
            <circle
              key={`${page}-${score}`}
              className={styles.peak}
              cx={xForIndex(page - 1, timeline.pageCount)}
              cy={yForScore(score)}
              r="4"
            />
          ))}
          <line className={styles.cursor} x1={currentX} y1={TOP} x2={currentX} y2={BOTTOM} />
          <circle className={styles.cursorDot} cx={currentX} cy={currentY} r="5" />
        </svg>
      </div>
    </div>
  );
}
