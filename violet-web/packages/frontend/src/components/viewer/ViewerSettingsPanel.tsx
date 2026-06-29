import { useTranslation } from 'react-i18next';
import { useViewerStore } from '../../stores/viewer-store';
import styles from './ViewerSettingsPanel.module.css';

export function ViewerSettingsPanel() {
  const { t } = useTranslation();
  const {
    viewMode,
    pageMode,
    readDirection,
    twoPageMode,
    coverPageMode,
    padding,
    setViewMode,
    setPageMode,
    setReadDirection,
    setTwoPageMode,
    setCoverPageMode,
    setPadding,
    toggleSettings,
  } = useViewerStore();

  return (
    <div className={styles.overlay} onClick={toggleSettings}>
      <div className={styles.panel} onClick={(e) => e.stopPropagation()}>
        <div className={styles.header}>
          <h3>{t('viewer.settingsPanel.title')}</h3>
          <button className={styles.closeBtn} onClick={toggleSettings}>
            ×
          </button>
        </div>

        <div className={styles.content}>
          {/* Page Mode */}
          <div className={styles.section}>
            <label className={styles.label}>{t('viewer.settingsPanel.pageMode.title')}</label>
            <div className={styles.buttons}>
              <button
                className={`${styles.btn} ${pageMode === 'scroll' ? styles.active : ''}`}
                onClick={() => setPageMode('scroll')}
              >
                {t('viewer.settingsPanel.pageMode.scroll')}
              </button>
              <button
                className={`${styles.btn} ${pageMode === 'paged' ? styles.active : ''}`}
                onClick={() => setPageMode('paged')}
              >
                {t('viewer.settingsPanel.pageMode.paged')}
              </button>
            </div>
          </div>

          {/* View Mode (for scroll mode) */}
          {pageMode === 'scroll' && (
            <div className={styles.section}>
              <label className={styles.label}>{t('viewer.settingsPanel.viewMode.title')}</label>
              <div className={styles.buttons}>
                <button
                  className={`${styles.btn} ${viewMode === 'vertical' ? styles.active : ''}`}
                  onClick={() => setViewMode('vertical')}
                >
                  {t('viewer.settingsPanel.viewMode.vertical')}
                </button>
                <button
                  className={`${styles.btn} ${viewMode === 'horizontal' ? styles.active : ''}`}
                  onClick={() => setViewMode('horizontal')}
                >
                  {t('viewer.settingsPanel.viewMode.horizontal')}
                </button>
              </div>
            </div>
          )}

          {/* Page Layout */}
          <div className={styles.section}>
            <label className={styles.label}>{t('viewer.settingsPanel.twoPageMode.title')}</label>
            <div className={styles.buttons}>
              <button
                className={`${styles.btn} ${!twoPageMode ? styles.active : ''}`}
                onClick={() => setTwoPageMode(false)}
              >
                {t('viewer.settingsPanel.twoPageMode.disabled')}
              </button>
              <button
                className={`${styles.btn} ${twoPageMode ? styles.active : ''}`}
                onClick={() => setTwoPageMode(true)}
              >
                {t('viewer.settingsPanel.twoPageMode.enabled')}
              </button>
            </div>
          </div>

          {/* Read Direction */}
          <div className={styles.section}>
            <label className={styles.label}>{t('viewer.settingsPanel.readDirection.title')}</label>
            <div className={styles.buttons}>
              <button
                className={`${styles.btn} ${readDirection === 'ltr' ? styles.active : ''}`}
                onClick={() => setReadDirection('ltr')}
              >
                {t('viewer.settingsPanel.readDirection.ltr')}
              </button>
              <button
                className={`${styles.btn} ${readDirection === 'rtl' ? styles.active : ''}`}
                onClick={() => setReadDirection('rtl')}
              >
                {t('viewer.settingsPanel.readDirection.rtl')}
              </button>
            </div>
          </div>

          {/* Cover Page Mode (only for two-page mode) */}
          {twoPageMode && (
            <div className={styles.section}>
              <label className={styles.label}>{t('viewer.settingsPanel.coverPageMode.title')}</label>
              <div className={styles.buttons}>
                <button
                  className={`${styles.btn} ${coverPageMode === 'cover' ? styles.active : ''}`}
                  onClick={() => setCoverPageMode('cover')}
                >
                  {t('viewer.settingsPanel.coverPageMode.cover')}
                </button>
                <button
                  className={`${styles.btn} ${coverPageMode === 'normal' ? styles.active : ''}`}
                  onClick={() => setCoverPageMode('normal')}
                >
                  {t('viewer.settingsPanel.coverPageMode.normal')}
                </button>
              </div>
            </div>
          )}

          {/* Padding (for vertical scroll) */}
          {pageMode === 'scroll' && viewMode === 'vertical' && (
            <div className={styles.section}>
              <label className={styles.label}>{t('viewer.settingsPanel.padding.title')}: {padding}px</label>
              <input
                type="range"
                min={0}
                max={50}
                value={padding}
                onChange={(e) => setPadding(Number(e.target.value))}
                className={styles.slider}
              />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
