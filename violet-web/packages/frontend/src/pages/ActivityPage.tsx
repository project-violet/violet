import { useMemo, useState, type MouseEvent } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { createPortal } from 'react-dom';
import { Bookmark, CalendarDays, Crop, Download, Eye, TrendingUp, X } from 'lucide-react';
import type { Article } from '@violet-web/shared';
import { getUserActivity, type ActivityDay, type UserActivity } from '../api/activity';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import { useAllArticles } from '../hooks/useAllArticles';
import { ArticleInfoDialog } from '../components/search/ArticleInfoDialog';
import { WorkThumbnail } from '../components/common/WorkThumbnail';
import styles from './ActivityPage.module.css';
import { filterActivityPeriod } from './activity-period';

const PERIODS = [30, 90, 365, 0] as const;
type RankMetric = 'reads' | 'recordedSeconds' | 'averageSessionSeconds' | 'secondsPerPageEstimate';
type RankedArticle = UserActivity['topArticles'][number];

function RankingRow({ item, index, work, detail, metric, metricLabel, onSelect }: {
  item: RankedArticle;
  index: number;
  work?: Article;
  detail: string;
  metric: string;
  metricLabel: string;
  onSelect: (article: Article) => void;
}) {
  return (
    <button className={styles.rankItem} type="button" onClick={() => work && onSelect(work)} disabled={!work}>
      <strong className={styles.rankNumber}>{index + 1}</strong>
      <WorkThumbnail articleId={Number(item.articleId)} size="activity" />
      <span className={styles.rankTitle}><strong>{work?.Title ?? `#${item.articleId}`}</strong><small>{detail}</small></span>
      <span className={styles.rankMetrics}><b>{metric}</b><small>{metricLabel}</small></span>
    </button>
  );
}

function ActivityChart({ days, labels }: { days: ActivityDay[]; labels: { total: string; reads: string; bookmarks: string; crops: string; downloads: string } }) {
  const [hovered, setHovered] = useState<{ index: number; left: number } | null>(null);
  const width = 900;
  const height = 220;
  const max = Math.max(1, ...days.map((day) => day.total));
  const points = days.map((day, index) => {
    const x = days.length === 1 ? width / 2 : (index / (days.length - 1)) * width;
    const y = height - (day.total / max) * (height - 24);
    return `${x},${y}`;
  });
  const area = points.length ? `0,${height} ${points.join(' ')} ${width},${height}` : '';
  const hoverDay = hovered ? days[hovered.index] : undefined;
  const hoverTop = hoverDay ? 100 - (hoverDay.total / max) * ((height - 24) / height) * 100 : 0;

  const handleMove = (event: MouseEvent<HTMLDivElement>) => {
    if (days.length === 0) return;
    const rect = event.currentTarget.getBoundingClientRect();
    const left = Math.max(0, Math.min(rect.width, event.clientX - rect.left));
    const index = Math.round((left / rect.width) * (days.length - 1));
    setHovered({ index, left: (index / Math.max(1, days.length - 1)) * 100 });
  };

  return (
    <div className={styles.chartWrap} onMouseMove={handleMove} onMouseLeave={() => setHovered(null)}>
      {days.length ? (
        <svg className={styles.chart} viewBox={`0 0 ${width} ${height}`} preserveAspectRatio="none" role="img">
          <defs>
            <linearGradient id="activity-fill" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="var(--color-primary)" stopOpacity="0.55" />
              <stop offset="100%" stopColor="var(--color-primary)" stopOpacity="0.03" />
            </linearGradient>
          </defs>
          <polygon points={area} fill="url(#activity-fill)" />
          <polyline points={points.join(' ')} fill="none" stroke="var(--color-primary)" strokeWidth="3" vectorEffect="non-scaling-stroke" />
        </svg>
      ) : <div className={styles.emptyChart}>—</div>}
      {hovered && hoverDay && <>
        <span className={styles.guideX} style={{ left: `${hovered.left}%` }} />
        <span className={styles.guideY} style={{ top: `${hoverTop}%` }} />
        <span className={styles.chartDot} style={{ left: `${hovered.left}%`, top: `${hoverTop}%` }} />
        <div className={`${styles.chartTooltip} ${hovered.left > 72 ? styles.tooltipLeft : ''}`} style={{ left: `${hovered.left}%`, top: `${Math.max(5, hoverTop - 8)}%` }}>
          <strong>{hoverDay.date}</strong>
          <span>{hoverDay.total.toLocaleString()} {labels.total}</span>
          <small>{labels.reads} {hoverDay.reads} · {labels.bookmarks} {hoverDay.bookmarks} · {labels.crops} {hoverDay.crops} · {labels.downloads} {hoverDay.downloads}</small>
        </div>
      </>}
    </div>
  );
}

export function ActivityPage() {
  const { t, i18n } = useTranslation();
  const [period, setPeriod] = useState<(typeof PERIODS)[number]>(90);
  const [rankBy, setRankBy] = useState<RankMetric>('reads');
  const [selectedArticle, setSelectedArticle] = useState<Article | null>(null);
  const [showRankingDialog, setShowRankingDialog] = useState(false);
  const { data, isLoading, isError } = useQuery({ queryKey: ['userActivity'], queryFn: getUserActivity });
  const days = useMemo(() => filterActivityPeriod(data?.days ?? [], period), [data, period]);
  const periodTotal = days.reduce((sum, day) => sum + day.total, 0);
  const activeDays = days.filter((day) => day.total > 0).length;
  const average = activeDays ? periodTotal / activeDays : 0;
  const number = (value: number) => value.toLocaleString(i18n.language);
  const duration = (seconds: number) => {
    if (seconds <= 0) return '—';
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    if (hours) return `${hours}${t('activity.time.hours')} ${minutes}${t('activity.time.minutes')}`;
    return `${minutes}${t('activity.time.minutes')} ${Math.round(seconds % 60)}${t('activity.time.seconds')}`;
  };
  const formatDate = (value: string) => new Intl.DateTimeFormat(i18n.language, { dateStyle: 'medium' }).format(new Date(value));
  const rankedArticles = useMemo(() => [...(data?.topArticles ?? [])]
    .sort((a, b) => b[rankBy] - a[rankBy] || b.total - a.total), [data, rankBy]);
  const topRankingArticles = rankedArticles.slice(0, 50);
  const visibleRankingArticles = topRankingArticles.slice(0, 8);
  const { data: rankedWorks } = useAllArticles('activity-ranking', topRankingArticles.map((item) => item.articleId));
  const workById = new Map(rankedWorks?.map((work) => [String(work.Id), work]));
  const rankDetail = (item: RankedArticle) => `#${item.articleId} · ${number(item.reads)}${t('activity.time.sessions')} · ${duration(item.recordedSeconds)} ${t('activity.time.recorded')}`;
  const rankMetric = (item: RankedArticle) => rankBy === 'reads' ? number(item.reads) : duration(item[rankBy]);

  if (isLoading) return <LoadingSpinner />;
  if (isError || !data) return <div className={styles.message}>{t('activity.error')}</div>;

  const cards = [
    ['reads', data.totals.reads],
    ['bookmarks', data.totals.bookmarks],
    ['crops', data.totals.crops],
    ['downloads', data.totals.downloads],
    ['uniqueWorks', data.totals.uniqueArticles],
  ] as const;
  const mixCards = [
    ['reads', data.totals.reads, Eye],
    ['bookmarks', data.totals.bookmarks, Bookmark],
    ['crops', data.totals.crops, Crop],
    ['downloads', data.totals.downloads, Download],
  ] as const;

  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <div>
          <h1>{t('activity.heading')}</h1>
          <p>{t('activity.subtitle')}</p>
        </div>
        {data.firstActivityAt && data.lastActivityAt && (
          <div className={styles.dateSpan}><CalendarDays size={17} />{formatDate(data.firstActivityAt)} – {formatDate(data.lastActivityAt)}</div>
        )}
      </header>

      <section className={styles.stats}>
        {cards.map(([key, value]) => (
          <article className={styles.statCard} key={key}>
            <span>{t(`activity.${key}`)}</span>
            <strong>{number(value)}</strong>
          </article>
        ))}
      </section>

      <section className={styles.panel}>
        <div className={styles.panelHeader}>
          <div><h2>{t('activity.trend')}</h2><p>{t('activity.periodSummary', { total: number(periodTotal), days: number(activeDays), average: average.toFixed(1) })}</p></div>
          <div className={styles.periods}>
            {PERIODS.map((value) => <button key={value} className={period === value ? styles.active : ''} onClick={() => setPeriod(value)}>{value ? t('activity.days', { count: value }) : t('activity.all')}</button>)}
          </div>
        </div>
        <ActivityChart days={days} labels={{ total: t('activity.actions'), reads: t('activity.reads'), bookmarks: t('activity.bookmarks'), crops: t('activity.crops'), downloads: t('activity.downloads') }} />
        <div className={styles.chartDates}><span>{days[0]?.date ?? '—'}</span><span>{days.at(-1)?.date ?? '—'}</span></div>
      </section>

      <div className={styles.lowerGrid}>
        <section className={styles.panel}>
          <div className={styles.panelHeader}><div><h2>{t('activity.mix')}</h2><p>{t('activity.mixSubtitle')}</p></div><TrendingUp size={20} /></div>
          <div className={styles.mixList}>
            {mixCards.map(([key, value, Icon]) => {
              const ratio = data.totals.total ? (value / data.totals.total) * 100 : 0;
              return <div className={styles.mixRow} key={key}><span><Icon size={16} />{t(`activity.${key}`)}</span><div><i style={{ width: `${ratio}%` }} /></div><strong>{ratio.toFixed(1)}%</strong></div>;
            })}
          </div>
        </section>

        <section className={styles.panel}>
          <div className={styles.panelHeader}>
            <div><h2>{t('activity.ranking')}</h2><p>{t('activity.rankingSubtitle')}</p></div>
            <div className={styles.rankTabs}>
              {(['reads', 'recordedSeconds', 'averageSessionSeconds', 'secondsPerPageEstimate'] as const).map((key) => <button key={key} className={rankBy === key ? styles.active : ''} onClick={() => setRankBy(key)}>{t(`activity.rank.${key}`)}</button>)}
            </div>
          </div>
          <div className={styles.rankingList}>
            {visibleRankingArticles.length === 0 && <div className={styles.empty}>{t('activity.empty')}</div>}
            {visibleRankingArticles.map((item, index) => <RankingRow key={item.articleId} item={item} index={index} work={workById.get(item.articleId)} detail={rankDetail(item)} metric={rankMetric(item)} metricLabel={t(`activity.rank.${rankBy}`)} onSelect={setSelectedArticle} />)}
          </div>
          {topRankingArticles.length > 8 && <button className={styles.moreButton} type="button" onClick={() => setShowRankingDialog(true)}>{t('activity.showMore')}</button>}
        </section>
      </div>
      {showRankingDialog && createPortal(
        <div className={styles.rankingOverlay} onClick={() => setShowRankingDialog(false)}>
          <div className={styles.rankingDialog} role="dialog" aria-modal="true" aria-labelledby="activity-ranking-dialog-title" onClick={(event) => event.stopPropagation()}>
            <header className={styles.rankingDialogHeader}>
              <div><h2 id="activity-ranking-dialog-title">{t('activity.rankingDialog')}</h2><span>{t(`activity.rank.${rankBy}`)} · {topRankingArticles.length}</span></div>
              <button type="button" onClick={() => setShowRankingDialog(false)} aria-label={t('activity.close')}><X size={18} /></button>
            </header>
            <div className={styles.rankingDialogList}>
              {topRankingArticles.map((item, index) => <RankingRow key={item.articleId} item={item} index={index} work={workById.get(item.articleId)} detail={rankDetail(item)} metric={rankMetric(item)} metricLabel={t(`activity.rank.${rankBy}`)} onSelect={setSelectedArticle} />)}
            </div>
          </div>
        </div>,
        document.body,
      )}
      {selectedArticle && <ArticleInfoDialog article={selectedArticle} onClose={() => setSelectedArticle(null)} />}
    </div>
  );
}
