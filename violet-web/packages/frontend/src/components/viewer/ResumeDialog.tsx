import { useTranslation } from 'react-i18next';
import styles from './ResumeDialog.module.css';

interface ResumeDialogProps {
  lastPage: number;
  totalPages: number;
  onResume: () => void;
  onStartOver: () => void;
}

export function ResumeDialog({ lastPage, totalPages, onResume, onStartOver }: ResumeDialogProps) {
  const { t } = useTranslation();

  return (
    <div className={styles.overlay} onClick={onStartOver}>
      <div className={styles.dialog} onClick={(e) => e.stopPropagation()}>
        <h3>{t('viewer.resume.title')}</h3>
        <p className={styles.message}>
          {t('viewer.resume.message', { page: lastPage + 1, total: totalPages })}
        </p>
        <div className={styles.actions}>
          <button className={styles.resumeBtn} onClick={onResume}>
            {t('viewer.resume.resume')}
          </button>
          <button className={styles.cancelBtn} onClick={onStartOver}>
            {t('viewer.resume.startOver')}
          </button>
        </div>
      </div>
    </div>
  );
}
