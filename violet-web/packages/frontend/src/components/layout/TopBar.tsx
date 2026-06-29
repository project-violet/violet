import { useNavigate, useSearchParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { SearchBar } from '../search/SearchBar';
import { useSearch } from '../../hooks/useSearch';
import { useAppStore } from '../../stores/app-store';
import styles from './TopBar.module.css';

export function TopBar() {
  const navigate = useNavigate();
  const { t } = useTranslation();
  const [searchParams] = useSearchParams();
  const query = searchParams.get('q') || '';
  const { contentLanguage, themeColor } = useAppStore();

  const fullQuery = contentLanguage !== 'all' ? `${query} lang:${contentLanguage}` : query;
  const { data } = useSearch(fullQuery || ' ', 0);

  const logoSrc = themeColor === 'purple'
    ? '/logos/logo.png'
    : `/logos/logo-${themeColor}.png`;

  return (
    <header className={styles.topbar}>
      <div className={styles.brand} onClick={() => navigate('/')}>
        <img src={logoSrc} alt="Violet" className={styles.logo} />
      </div>
      <div className={styles.searchWrapper}>
        <SearchBar />
      </div>
      {data && (
        <div className={styles.results}>
          <span className={styles.count}>{t('home.results', { count: data.totalCount })}</span>
        </div>
      )}
    </header>
  );
}
