import { useMemo } from 'react';
import type { MessageSearchResult } from '@violet-web/shared';
import { useColumnCount } from '../../hooks/useColumnCount';
import { MessageSearchCard } from './MessageSearchCard';
import styles from './MessageSearchGrid.module.css';

interface MessageSearchGridProps {
  results: MessageSearchResult[];
  columnWidth: number;
}

function distributeToColumns(results: MessageSearchResult[], columnCount: number) {
  const columns: MessageSearchResult[][] = Array.from({ length: columnCount }, () => []);
  results.forEach((result, index) => {
    columns[index % columnCount].push(result);
  });
  return columns;
}

export function MessageSearchGrid({ results, columnWidth }: MessageSearchGridProps) {
  const columnCount = useColumnCount(columnWidth);
  const columns = useMemo(
    () => distributeToColumns(results, columnCount),
    [results, columnCount],
  );

  return (
    <div className={styles.grid}>
      {columns.map((column, index) => (
        <div key={index} className={styles.column}>
          {column.map((result, itemIndex) => (
            <MessageSearchCard
              key={`${result.articleId}-${result.page}-${itemIndex}`}
              result={result}
            />
          ))}
        </div>
      ))}
    </div>
  );
}
