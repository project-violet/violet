import type { TagChipData } from '../../hooks/useArticleTagSummary';
import styles from './TagChips.module.css';

interface TagChipsProps {
  tags: TagChipData[];
  selectedTags: Set<string>;
  onToggle: (display: string) => void;
  className?: string;
}

const prefixClass: Record<string, string> = {
  female: styles.female,
  male: styles.male,
  tag: styles.tag,
  artist: styles.artist,
  series: styles.series,
  group: styles.group,
  character: styles.character,
};

export function TagChips({ tags, selectedTags, onToggle, className }: TagChipsProps) {
  if (tags.length === 0) {
    return null;
  }

  return (
    <div className={`${styles.container} ${className ?? ''}`}>
      {tags.map((tag) => {
        const isSelected = selectedTags.has(tag.display);
        const tagName = tag.tag.replace(/_/g, ' ');
        const pClass = prefixClass[tag.category] || styles.tag;
        return (
          <button
            key={tag.display}
            type="button"
            className={`${styles.chip} ${isSelected ? styles.active : ''}`}
            onClick={() => onToggle(tag.display)}
          >
            <span className={`${styles.prefix} ${pClass}`}>{tag.category}:</span>
            {tagName}
            <span className={styles.count}>{tag.count}</span>
          </button>
        );
      })}
    </div>
  );
}
