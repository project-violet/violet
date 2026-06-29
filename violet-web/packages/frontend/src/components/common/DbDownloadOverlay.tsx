import { useTranslation } from 'react-i18next';
import { useSyncStatus } from '../../hooks/useSync';
import styles from './DbDownloadOverlay.module.css';

export function DbDownloadOverlay() {
  const { t } = useTranslation();
  const { data: syncStatus } = useSyncStatus();

  if (!syncStatus) return null;

  const isDownloading = syncStatus.status === 'downloading_full' && !syncStatus.dbExists;
  const isBuildingCache = syncStatus.status === 'building_cache' && !syncStatus.dbExists;

  if (!isDownloading && !isBuildingCache) return null;

  const progress = syncStatus.progress;
  const percent = progress ? (progress.current / progress.total) * 100 : 0;

  return (
    <div className={styles.overlay}>
      <div className={styles.content}>
        <h2 className={styles.title}>
          {isBuildingCache
            ? t('sync.downloadOverlay.cacheTitle')
            : t('sync.downloadOverlay.title')}
        </h2>
        <p className={styles.message}>
          {isBuildingCache
            ? t('sync.downloadOverlay.cacheMessage')
            : t('sync.downloadOverlay.message')}
        </p>
        {isBuildingCache ? (
          <div className={styles.spinner} />
        ) : progress ? (
          <div className={styles.progressWrapper}>
            <div className={styles.progressBar}>
              <div
                className={styles.progressFill}
                style={{ width: `${percent}%` }}
              />
            </div>
            <div className={styles.progressText}>
              {progress.message}
            </div>
          </div>
        ) : null}
      </div>
    </div>
  );
}
