import { useState, useEffect } from 'react';

/**
 * Returns the number of columns that fit the current window width,
 * given a minimum column width in pixels.
 */
export function useColumnCount(minColumnWidth: number): number {
  const [count, setCount] = useState(() =>
    Math.max(1, Math.floor(window.innerWidth / minColumnWidth)),
  );

  useEffect(() => {
    const update = () => {
      setCount(Math.max(1, Math.floor(window.innerWidth / minColumnWidth)));
    };
    update();
    window.addEventListener('resize', update);
    return () => window.removeEventListener('resize', update);
  }, [minColumnWidth]);

  return count;
}
