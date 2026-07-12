import type { RefObject } from 'react';
import { useTranslation } from 'react-i18next';
import { SearchBar, type SearchBarRef } from './SearchBar';
import { TagChips } from './TagChips';
import type { TagChipData } from '../../hooks/useArticleTagSummary';
import type { TagEntry } from '@violet-web/shared';
import { useAppStore } from '../../stores/app-store';
import styles from './LocalSearchSection.module.css';

interface LocalSearchSectionProps {
  basePath: string;
  searchBarRef: RefObject<SearchBarRef | null>;
  getSuggestions: (input: string) => TagEntry[];
  tagSummary: TagChipData[];
  selectedTags: Set<string>;
  onTagToggle: (display: string) => void;
  resultCount?: number;
  isLoading?: boolean;
  showViewControls?: boolean;
  sticky?: boolean;
  headerContent?: React.ReactNode;
  extraControls?: React.ReactNode;
  dateRangeContent?: React.ReactNode;
}

export function LocalSearchSection({
  basePath,
  searchBarRef,
  getSuggestions,
  tagSummary,
  selectedTags,
  onTagToggle,
  resultCount,
  isLoading,
  showViewControls = true,
  sticky = false,
  headerContent,
  extraControls,
  dateRangeContent,
}: LocalSearchSectionProps) {
  const { t } = useTranslation();
  const { viewMode, setViewMode, cardMinWidth, setCardMinWidth } = useAppStore();

  return (
    <div className={sticky ? styles.elevated : styles.container}>
      {headerContent}
      <div className={styles.searchBar}>
        <SearchBar
          ref={searchBarRef}
          getSuggestions={getSuggestions}
          basePath={basePath}
        />
        {dateRangeContent && <div className={styles.dateRange}>{dateRangeContent}</div>}
        {!dateRangeContent && !isLoading && resultCount !== undefined && resultCount > 0 && (
          <div className={styles.resultCount}>
            {t('home.results', { count: resultCount })}
          </div>
        )}
        {showViewControls && (
          <>
            <input
              type="range"
              className={styles.cardSizeSlider}
              min={120}
              max={350}
              step={10}
              value={cardMinWidth}
              onChange={(e) => setCardMinWidth(Number(e.target.value))}
            />
            <label className={styles.viewSwitch} title={viewMode === 'grid' ? 'Detail view' : 'Grid view'}>
              <span className={styles.switchLabel}>▦</span>
              <input
                type="checkbox"
                className={styles.switchInput}
                checked={viewMode === 'detail'}
                onChange={() => setViewMode(viewMode === 'grid' ? 'detail' : 'grid')}
              />
              <span className={styles.switchTrack}>
                <span className={styles.switchThumb} />
              </span>
              <span className={styles.switchLabel}>☰</span>
            </label>
          </>
        )}
        {extraControls}
      </div>

      {!isLoading && tagSummary.length > 0 && (
        <TagChips
          tags={tagSummary}
          selectedTags={selectedTags}
          onToggle={onTagToggle}
        />
      )}
    </div>
  );
}
