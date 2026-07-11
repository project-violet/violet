import { useState, useRef, useEffect, useMemo, forwardRef, useImperativeHandle, type FormEvent, type KeyboardEvent } from 'react';
import { createPortal } from 'react-dom';
import { useNavigate, useSearchParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useSearchStore } from '../../stores/search-store';
import { useAppStore } from '../../stores/app-store';
import { useContextualSuggestions } from '../../hooks/useContextualSuggestions';
import { useTagTranslation } from '../../hooks/useTagTranslation';
import type { TagEntry } from '@violet-web/shared';
import styles from './SearchBar.module.css';

type DropdownItem = TagEntry | string;

export interface SearchBarRef {
  focus: () => void;
}

export interface SearchBarProps {
  getSuggestions?: (input: string) => TagEntry[]; // Function to get local suggestions based on input
  basePath?: string; // Base path for navigation (default: '/')
}

export const SearchBar = forwardRef<SearchBarRef, SearchBarProps>(function SearchBar(props, ref) {
  const { getSuggestions, basePath = '/' } = props;
  const { t } = useTranslation();
  const [searchParams] = useSearchParams();
  const queryFromUrl = searchParams.get('q') || '';

  const [value, setValue] = useState(queryFromUrl);
  const [isOpen, setIsOpen] = useState(false);
  const [highlightedIndex, setHighlightedIndex] = useState(0);
  const [dropdownPosition, setDropdownPosition] = useState({ top: 0, left: 0, width: 0 });

  const inputRef = useRef<HTMLInputElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const dropdownRef = useRef<HTMLDivElement>(null);

  const navigate = useNavigate();
  const { recentSearches, addRecentSearch, clearRecentSearches } = useSearchStore();
  const contentLanguage = useAppStore((s) => s.contentLanguage);
  const contextualSuggestionCounts = useAppStore((s) => s.contextualSuggestionCounts);
  const languageContext = contentLanguage !== 'all' ? `lang:${contentLanguage}` : '';
  const { data: apiSuggestions, isLoading } = useContextualSuggestions(
    value,
    languageContext,
    20,
    contextualSuggestionCounts,
  );
  const { translateTag } = useTagTranslation();

  // Expose focus method to parent
  useImperativeHandle(ref, () => ({
    focus: () => {
      inputRef.current?.focus();
    },
  }));

  // Sync input value with URL query parameter
  useEffect(() => {
    setValue(queryFromUrl);
  }, [queryFromUrl]);

  // Extract last token to determine if we're in suggestion mode
  const lastToken = useMemo(() => {
    return value.trim().split(/\s+/).pop() || '';
  }, [value]);

  // Memoize suggestion mode and dropdown items to prevent flickering
  const { isSuggestionMode, dropdownItems } = useMemo(() => {
    // Use local suggestions if function provided, otherwise use API suggestions
    const suggestions = getSuggestions
      ? getSuggestions(value)
      : (apiSuggestions?.suggestions ?? []);
    const hasSuggestions = suggestions.length > 0;
    const inSuggestionMode = lastToken.length > 0 && hasSuggestions;

    const items: DropdownItem[] = inSuggestionMode
      ? suggestions
      : recentSearches.slice(0, 10);

    return { isSuggestionMode: inSuggestionMode, dropdownItems: items };
  }, [lastToken, value, getSuggestions, apiSuggestions, recentSearches]);

  // Update dropdown position when opening (but not on every render)
  useEffect(() => {
    if (isOpen && inputRef.current) {
      const rect = inputRef.current.getBoundingClientRect();
      setDropdownPosition((prev) => {
        const newPos = {
          top: rect.bottom + window.scrollY,
          left: rect.left + window.scrollX,
          width: rect.width,
        };
        // Only update if position actually changed to prevent flickering
        if (prev.top === newPos.top && prev.left === newPos.left && prev.width === newPos.width) {
          return prev;
        }
        return newPos;
      });
    }
  }, [isOpen]);

  // Reset highlighted index when items change
  useEffect(() => {
    setHighlightedIndex(0);
  }, [dropdownItems.length]);

  // Handle click outside
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (
        containerRef.current &&
        !containerRef.current.contains(e.target as Node) &&
        dropdownRef.current &&
        !dropdownRef.current.contains(e.target as Node)
      ) {
        setIsOpen(false);
      }
    };

    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside);
      return () => document.removeEventListener('mousedown', handleClickOutside);
    }
  }, [isOpen]);

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    const q = value.trim();
    if (!q) return;
    addRecentSearch(q);
    navigate(`${basePath}?q=${encodeURIComponent(q)}`);
    setIsOpen(false);
  };

  const handleFocus = () => {
    setIsOpen(true);
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if (!isOpen) {
      if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
        setIsOpen(true);
        e.preventDefault();
      }
      return;
    }

    switch (e.key) {
      case 'Escape':
        setIsOpen(false);
        e.preventDefault();
        break;

      case 'ArrowDown':
        setHighlightedIndex((prev) =>
          prev < dropdownItems.length - 1 ? prev + 1 : prev
        );
        e.preventDefault();
        break;

      case 'ArrowUp':
        setHighlightedIndex((prev) => (prev > 0 ? prev - 1 : 0));
        e.preventDefault();
        break;

      case 'Enter':
        if (dropdownItems.length > 0 && highlightedIndex < dropdownItems.length) {
          e.preventDefault();
          selectItem(dropdownItems[highlightedIndex]);
        }
        break;
    }
  };

  const selectItem = (item: DropdownItem) => {
    if (typeof item === 'string') {
      // Recent search - execute search immediately
      setValue(item);
      addRecentSearch(item);
      navigate(`${basePath}?q=${encodeURIComponent(item)}`);
      setIsOpen(false);
    } else {
      // TagEntry - replace the last token with the selected suggestion
      const tokens = value.trim().split(/\s+/);
      tokens[tokens.length - 1] = item.display;
      setValue(tokens.join(' ') + ' ');
      inputRef.current?.focus();
      setIsOpen(false);
    }
  };

  const handleClearRecent = () => {
    clearRecentSearches();
    setIsOpen(false);
  };

  // Memoize showDropdown to prevent flickering
  const showDropdown = useMemo(() => {
    return isOpen && dropdownItems.length > 0 && !isLoading;
  }, [isOpen, dropdownItems.length, isLoading]);

  return (
    <div className={styles.container} ref={containerRef}>
      <form className={styles.form} onSubmit={handleSubmit}>
        <input
          ref={inputRef}
          className={styles.input}
          type="text"
          value={value}
          onChange={(e) => setValue(e.target.value)}
          onFocus={handleFocus}
          onKeyDown={handleKeyDown}
          placeholder={t('search.placeholder')}
          role="combobox"
          aria-expanded={isOpen}
          aria-autocomplete="list"
          aria-controls="search-dropdown"
          aria-activedescendant={
            showDropdown ? `search-item-${highlightedIndex}` : undefined
          }
        />
      </form>

      {showDropdown &&
        createPortal(
          <div
            ref={dropdownRef}
            id="search-dropdown"
            className={styles.dropdown}
            style={{
              position: 'fixed',
              top: `${dropdownPosition.top}px`,
              left: `${dropdownPosition.left}px`,
              width: `${dropdownPosition.width}px`,
            }}
            role="listbox"
          >
            {!isSuggestionMode && (
              <div className={styles.dropdownHeader}>
                <span className={styles.dropdownLabel}>
                  {t('search.recentSearches')}
                </span>
                <button
                  type="button"
                  className={styles.clearBtn}
                  onClick={handleClearRecent}
                >
                  {t('search.clearRecent')}
                </button>
              </div>
            )}

            {dropdownItems.map((item, index) => (
              <button
                key={typeof item === 'string' ? `${item}-${index}` : `${item.display}-${index}`}
                id={`search-item-${index}`}
                type="button"
                className={`${styles.dropdownItem} ${
                  index === highlightedIndex ? styles.highlighted : ''
                }`}
                onClick={() => selectItem(item)}
                onMouseEnter={() => setHighlightedIndex(index)}
                role="option"
                aria-selected={index === highlightedIndex}
              >
                {typeof item === 'string' ? (
                  item
                ) : (
                  <>
                    <span className={styles.entryDisplay}>
                      {item.display}
                      {(() => {
                        const parts = item.display.split(':');
                        if (parts.length === 2) {
                          const ko = translateTag(parts[0], parts[1]);
                          if (ko) return ` (${ko})`;
                        }
                        return null;
                      })()}
                    </span>
                    <span className={styles.entryCount}>
                      {item.contextualCount !== undefined
                        ? `${item.contextualCount.toLocaleString()} (${item.count.toLocaleString()})`
                        : item.count.toLocaleString()}
                    </span>
                  </>
                )}
              </button>
            ))}
          </div>,
          document.body
        )}
    </div>
  );
});
