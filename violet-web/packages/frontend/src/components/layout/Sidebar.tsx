import { NavLink, useNavigate } from 'react-router';
import { useTranslation } from 'react-i18next';
import { Home, Bookmark, Crop, History, Download, Settings, ChevronLeft, ChevronRight, Sparkles, Flame, Sun, Moon, Monitor, MessageSquareText, Network, FlaskConical, UsersRound } from 'lucide-react';
import { DiscordIcon } from '../icons/DiscordIcon';
import { GithubIcon } from '../icons/GithubIcon';
import { useAppStore } from '../../stores/app-store';
import styles from './Sidebar.module.css';

const navItems = [
  { to: '/', labelKey: 'nav.home', icon: Home },
  { to: '/hot', labelKey: 'nav.hot', icon: Flame },
  { to: '/history', labelKey: 'nav.history', icon: History },
  { to: '/bookmarks', labelKey: 'nav.bookmarks', icon: Bookmark },
  { to: '/crop-bookmarks', labelKey: 'nav.cropBookmarks', icon: Crop },
  { to: '/downloads', labelKey: 'nav.downloads', icon: Download },
  { to: '/ai-search', labelKey: 'nav.aiSearch', icon: Sparkles },
  { to: '/message-search', labelKey: 'nav.messageSearch', icon: MessageSquareText },
  { to: '/keyword-graph', labelKey: 'nav.keywordGraph', icon: Network },
  { to: '/work-experiment', labelKey: 'nav.workExperiment', icon: FlaskConical },
  { to: '/author-similarity', labelKey: 'nav.authorSimilarity', icon: UsersRound },
  { to: '/settings', labelKey: 'nav.settings', icon: Settings },
];

export function Sidebar() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { themeColor, themeMode, sidebarCollapsed, toggleSidebar, setThemeMode, aiSearchEnabled, messageSearchEnabled } = useAppStore();

  const logoSrc = themeColor === 'purple'
    ? '/logos/logo.png'
    : `/logos/logo-${themeColor}.png`;

  return (
    <nav className={`${styles.sidebar} ${sidebarCollapsed ? styles.collapsed : ''}`}>
      <div className={styles.logoContainer} onClick={() => navigate('/')}>
        <img src={logoSrc} alt="Violet" className={styles.logo} />
        {!sidebarCollapsed && <div className={styles.logoText}>Project Violet</div>}
      </div>

      <div className={styles.navLinks}>
        {navItems.filter((item) =>
          (item.to !== '/ai-search' || aiSearchEnabled)
          && (item.to !== '/message-search' || messageSearchEnabled)
        ).map((item) => {
          const Icon = item.icon;
          return (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                `${styles.link} ${isActive ? styles.active : ''}`
              }
              title={sidebarCollapsed ? t(item.labelKey) : undefined}
            >
              <Icon size={20} className={styles.icon} />
              {!sidebarCollapsed && <span>{t(item.labelKey)}</span>}
            </NavLink>
          );
        })}
      </div>

      <div className={styles.socialLinks}>
        <a
          href="https://discord.com/invite/fqrtRxC"
          target="_blank"
          rel="noopener noreferrer"
          className={styles.socialLink}
          title="Discord"
        >
          <DiscordIcon size={20} className={styles.icon} />
          {!sidebarCollapsed && <span>Discord</span>}
        </a>
        <a
          href="https://github.com/project-violet/violet"
          target="_blank"
          rel="noopener noreferrer"
          className={styles.socialLink}
          title="GitHub"
        >
          <GithubIcon size={20} className={styles.icon} />
          {!sidebarCollapsed && <span>GitHub</span>}
        </a>
      </div>

      <div className={styles.themeToggle}>
        <button
          className={`${styles.themeBtn} ${themeMode === 'light' ? styles.active : ''}`}
          onClick={() => setThemeMode('light')}
          title="Light"
        >
          <Sun size={18} />
        </button>
        <button
          className={`${styles.themeBtn} ${themeMode === 'dark' ? styles.active : ''}`}
          onClick={() => setThemeMode('dark')}
          title="Dark"
        >
          <Moon size={18} />
        </button>
        <button
          className={`${styles.themeBtn} ${themeMode === 'system' ? styles.active : ''}`}
          onClick={() => setThemeMode('system')}
          title="System"
        >
          <Monitor size={18} />
        </button>
      </div>

      <button className={styles.toggleBtn} onClick={toggleSidebar}>
        {sidebarCollapsed ? <ChevronRight size={20} /> : <ChevronLeft size={20} />}
      </button>
    </nav>
  );
}
