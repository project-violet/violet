import { useViewerStore } from '../../stores/viewer-store';
import type { ViewMode, ReadDirection } from '../../stores/viewer-store';
import styles from './ViewerSettings.module.css';

export function ViewerSettings() {
  const {
    viewMode,
    readDirection,
    padding,
    setViewMode,
    setReadDirection,
    setPadding,
  } = useViewerStore();

  return (
    <div className={styles.panel}>
      <h3 className={styles.heading}>Viewer Settings</h3>

      <label className={styles.label}>
        View Mode
        <select
          value={viewMode}
          onChange={(e) => setViewMode(e.target.value as ViewMode)}
        >
          <option value="vertical">Vertical Scroll</option>
          <option value="horizontal">Horizontal</option>
        </select>
      </label>

      <label className={styles.label}>
        Read Direction
        <select
          value={readDirection}
          onChange={(e) => setReadDirection(e.target.value as ReadDirection)}
        >
          <option value="ltr">Left to Right</option>
          <option value="rtl">Right to Left</option>
        </select>
      </label>

      <label className={styles.label}>
        Padding ({padding}px)
        <input
          type="range"
          min={0}
          max={20}
          value={padding}
          onChange={(e) => setPadding(Number(e.target.value))}
        />
      </label>
    </div>
  );
}
