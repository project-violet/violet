import { useMemo } from 'react';
import type { LlmSearchResult } from '@violet-web/shared';
import { useColumnCount } from '../../hooks/useColumnCount';
import { LlmSearchCard } from './LlmSearchCard';
import styles from '../message-search/MessageSearchGrid.module.css';

interface LlmSearchGridProps {
  results: LlmSearchResult[];
  columnWidth: number;
}

export function LlmSearchGrid({ results, columnWidth }: LlmSearchGridProps) {
  const columnCount = useColumnCount(columnWidth);
  const columns = useMemo(() => {
    const distributed: LlmSearchResult[][] = Array.from({ length: columnCount }, () => []);
    results.forEach((result, index) => distributed[index % columnCount].push(result));
    return distributed;
  }, [results, columnCount]);

  return (
    <div className={styles.grid}>
      {columns.map((column, index) => (
        <div key={index} className={styles.column}>
          {column.map((result) => (
            <LlmSearchCard
              key={`${result.work}-${result.pages.join('-')}-${result.rank}`}
              result={result}
            />
          ))}
        </div>
      ))}
    </div>
  );
}
