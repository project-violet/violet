import { useNavigate } from 'react-router';
import { SearchBar } from '../search/SearchBar';
import { useAppStore } from '../../stores/app-store';
import styles from './TopBar.module.css';

export function TopBar() {
  const navigate = useNavigate();
  const { themeColor } = useAppStore();

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
    </header>
  );
}
