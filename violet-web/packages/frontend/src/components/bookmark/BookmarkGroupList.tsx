import { useTranslation } from 'react-i18next';
import type { BookmarkGroup } from '@violet-web/shared';
import styles from './BookmarkGroupList.module.css';

interface BookmarkGroupListProps {
  groups: BookmarkGroup[];
  selectedId: number | undefined;
  onSelect: (id: number | undefined) => void;
}

export function BookmarkGroupList({ groups, selectedId, onSelect }: BookmarkGroupListProps) {
  const { t } = useTranslation();

  const getGroupName = (group: BookmarkGroup) => {
    return group.Name === 'violet_default' ? t('bookmarks.uncategorized') : group.Name;
  };

  return (
    <div className={styles.list}>
      <button
        className={`${styles.item} ${selectedId === undefined ? styles.active : ''}`}
        onClick={() => onSelect(undefined)}
      >
        {t('bookmarks.all')}
      </button>
      {groups.map((g) => (
        <button
          key={g.Id}
          className={`${styles.item} ${selectedId === g.Id ? styles.active : ''}`}
          onClick={() => onSelect(g.Id)}
        >
          {getGroupName(g)}
        </button>
      ))}
    </div>
  );
}
