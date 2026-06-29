import { useTranslation } from 'react-i18next';
import { Sparkles } from 'lucide-react';
import styles from './AiAnswerCard.module.css';

interface AiAnswerCardProps {
  answer: string;
}

export function AiAnswerCard({ answer }: AiAnswerCardProps) {
  const { t } = useTranslation();

  return (
    <div className={styles.card}>
      <div className={styles.header}>
        <Sparkles size={18} className={styles.icon} />
        <span className={styles.label}>{t('aiSearch.answerLabel')}</span>
      </div>
      <div className={styles.body}>{answer}</div>
    </div>
  );
}
