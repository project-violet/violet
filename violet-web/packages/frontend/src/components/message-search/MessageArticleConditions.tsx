import { useTranslation } from 'react-i18next';
import { Tags, X } from 'lucide-react';
import { SearchBar } from '../search/SearchBar';
import styles from '../../pages/MessageSearchPage.module.css';

export function MessageArticleConditions({ value, onChange }: { value: string; onChange: (query: string) => void }) {
  const { t } = useTranslation();
  return <div className={styles.inputWrapper}>
    <Tags size={18} className={styles.searchIcon} />
    <SearchBar embedded value={value} onChange={onChange} contextQuery=""
      ariaLabel={t('messageSearch.articleConditions')}
      placeholder={t('messageSearch.articleConditionsPlaceholder')}
      inputClassName={`${styles.searchInput} ${styles.articleConditionsInput}`} />
    {value && <button className={styles.clearConditions} type="button" onClick={() => onChange('')}
      aria-label={t('messageSearch.clearConditions')} title={t('messageSearch.clearConditions')}><X size={16} /></button>}
  </div>;
}
