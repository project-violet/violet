import { useEffect, useMemo, useState } from 'react';
import { NavLink } from 'react-router';
import { useTranslation } from 'react-i18next';
import {
  Activity,
  Beaker,
  Bookmark,
  BrainCircuit,
  Clock3,
  Download,
  Home,
  Menu,
  MessageSquare,
  Network,
  Scissors,
  Settings,
  Sparkles,
  UsersRound,
  X,
} from 'lucide-react';
import { useLocation } from 'react-router';
import { useAppStore } from '../../stores/app-store';
import styles from './BottomNav.module.css';

const navItems = [
  { to: '/', labelKey: 'nav.home', icon: Home },
  { to: '/history', labelKey: 'nav.history', icon: Clock3 },
  { to: '/bookmarks', labelKey: 'nav.bookmarks', icon: Bookmark },
  { to: '/settings', labelKey: 'nav.settings', icon: Settings },
];

const moreItems = [
  { to: '/crop-bookmarks', labelKey: 'nav.cropBookmarks', icon: Scissors },
  { to: '/downloads', labelKey: 'nav.downloads', icon: Download },
  { to: '/ai-search', labelKey: 'nav.aiSearch', icon: Sparkles, feature: 'ai' },
  { to: '/message-search', labelKey: 'nav.messageSearch', icon: MessageSquare, feature: 'message' },
  { to: '/llm-search', labelKey: 'nav.llmSearch', icon: BrainCircuit, feature: 'llm' },
  { to: '/keyword-graph', labelKey: 'nav.keywordGraph', icon: Network },
  { to: '/work-experiment', labelKey: 'nav.workExperiment', icon: Beaker },
  { to: '/author-similarity', labelKey: 'nav.authorSimilarity', icon: UsersRound },
  { to: '/activity', labelKey: 'nav.activity', icon: Activity },
];

export function BottomNav() {
  const { t } = useTranslation();
  const location = useLocation();
  const [isMoreOpen, setIsMoreOpen] = useState(false);
  const { aiSearchEnabled, messageSearchEnabled, llmSearchEnabled } = useAppStore();
  const visibleMoreItems = useMemo(
    () => moreItems.filter((item) =>
      (item.feature !== 'ai' || aiSearchEnabled)
      && (item.feature !== 'message' || messageSearchEnabled)
      && (item.feature !== 'llm' || llmSearchEnabled)
    ),
    [aiSearchEnabled, llmSearchEnabled, messageSearchEnabled],
  );
  const isMoreActive = visibleMoreItems.some((item) => item.to === location.pathname);

  useEffect(() => {
    setIsMoreOpen(false);
  }, [location.pathname]);

  return (
    <>
      {isMoreOpen && (
        <div className={styles.moreLayer}>
          <button
            type="button"
            className={styles.backdrop}
            onClick={() => setIsMoreOpen(false)}
            aria-label={t('search.collapseTags')}
          />
          <section className={styles.moreSheet} role="dialog" aria-modal="true" aria-label={t('nav.more')}>
            <div className={styles.moreHeader}>
              <strong>{t('nav.more')}</strong>
              <button
                type="button"
                className={styles.closeButton}
                onClick={() => setIsMoreOpen(false)}
                aria-label={t('nav.more')}
              >
                <X size={20} aria-hidden="true" />
              </button>
            </div>
            <div className={styles.moreGrid}>
              {visibleMoreItems.map((item) => {
                const Icon = item.icon;
                return (
                  <NavLink
                    key={item.to}
                    to={item.to}
                    className={({ isActive }) =>
                      `${styles.moreLink} ${isActive ? styles.moreLinkActive : ''}`
                    }
                  >
                    <Icon size={21} aria-hidden="true" />
                    <span>{t(item.labelKey)}</span>
                  </NavLink>
                );
              })}
            </div>
          </section>
        </div>
      )}
      <nav className={styles.nav} aria-label={t('app.name')}>
        <div className={styles.navInner}>
          {navItems.map((item) => {
            const Icon = item.icon;
            return (
              <NavLink
                key={item.to}
                to={item.to}
                end={item.to === '/'}
                aria-label={t(item.labelKey)}
                className={({ isActive }) =>
                  `${styles.link} ${isActive ? styles.active : ''}`
                }
              >
                <span className={styles.iconWrap}>
                  <Icon size={21} strokeWidth={2.1} aria-hidden="true" />
                </span>
                <span className={styles.label}>{t(item.labelKey)}</span>
              </NavLink>
            );
          })}
          <button
            type="button"
            className={`${styles.link} ${styles.moreButton} ${isMoreActive || isMoreOpen ? styles.active : ''}`}
            onClick={() => setIsMoreOpen((value) => !value)}
            aria-expanded={isMoreOpen}
            aria-label={t('nav.more')}
          >
            <span className={styles.iconWrap}>
              <Menu size={21} strokeWidth={2.1} aria-hidden="true" />
            </span>
            <span className={styles.label}>{t('nav.more')}</span>
          </button>
        </div>
      </nav>
    </>
  );
}
