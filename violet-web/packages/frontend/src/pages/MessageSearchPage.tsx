import { useEffect } from 'react';
import { useSearchParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import type { MessageSearchMode } from '@violet-web/shared';
import { MessageSearchPanel } from '../components/message-search/MessageSearchPanel';
import { DateRangeFilter } from '../components/search/DateRangeFilter';
import styles from './MessageSearchPage.module.css';

export function MessageSearchPage() {
  const { t } = useTranslation();
  const [params, setParams] = useSearchParams();
  const query = params.get('q') || '';
  const rawMode = params.get('mode') || 'contains';
  const mode: MessageSearchMode = rawMode === 'similar' || rawMode === 'lcs' ? rawMode : 'contains';
  const from = params.get('from') || undefined;
  const to = params.get('to') || undefined;
  const idMin = params.get('idMin');
  const idMax = params.get('idMax');
  useEffect(() => {
    document.title = query ? `${query} - ${t('messageSearch.heading')}` : `${t('messageSearch.heading')} - Violet`;
    return () => { document.title = 'Violet'; };
  }, [query, t]);
  return <MessageSearchPanel query={query} mode={mode}
    filters={{ from, to, idMin: idMin ? Number(idMin) : undefined, idMax: idMax ? Number(idMax) : undefined }}
    onSearch={(q, nextMode) => {
      const next = new URLSearchParams(params);
      next.set('q', q);
      if (nextMode === 'contains') next.delete('mode'); else next.set('mode', nextMode);
      setParams(next);
    }}
    dateRange={<div className={styles.dateRange} title={t('messageSearch.dateRangeHint')}>
      <DateRangeFilter query="lang:korean" from={from} to={to} compact onCommit={(nextFrom, nextTo) => {
        const next = new URLSearchParams(params);
        if (nextFrom) next.set('from', nextFrom); else next.delete('from');
        if (nextTo) next.set('to', nextTo); else next.delete('to');
        next.delete('idMin'); next.delete('idMax'); setParams(next);
      }} />
    </div>} />;
}
