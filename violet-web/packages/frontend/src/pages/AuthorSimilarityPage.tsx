import { FormEvent, useEffect, useRef, useState } from 'react';
import { useSearchParams } from 'react-router';
import { Loader2, Search, UsersRound } from 'lucide-react';
import {
  fetchAuthorSimilarity,
  type AuthorSimilarityGroup,
  type AuthorSimilarityResponse,
} from '../api/author-similarity';
import { ArticleCard } from '../components/search/ArticleCard';
import { useAppStore } from '../stores/app-store';
import styles from './AuthorSimilarityPage.module.css';

export function AuthorSimilarityPage() {
  const [searchParams, setSearchParams] = useSearchParams();
  const contentLanguage = useAppStore((state) => state.contentLanguage);
  const authorFromUrl = searchParams.get('author') || '';
  const [author, setAuthor] = useState(authorFromUrl);
  const [result, setResult] = useState<AuthorSimilarityResponse | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const requestSeq = useRef(0);

  const runSearch = async (authorValue: string) => {
    const trimmedAuthor = authorValue.trim();
    if (!trimmedAuthor) {
      setError('작가를 입력해 주세요.');
      return;
    }

    setLoading(true);
    setError('');
    const seq = requestSeq.current + 1;
    requestSeq.current = seq;
    try {
      const response = await fetchAuthorSimilarity(trimmedAuthor, 20, contentLanguage);
      if (requestSeq.current !== seq) return;
      setResult(response);
    } catch (err) {
      if (requestSeq.current !== seq) return;
      setResult(null);
      setError(err instanceof Error ? err.message : '유사 작가 정보를 불러오지 못했습니다.');
    } finally {
      if (requestSeq.current === seq) {
        setLoading(false);
      }
    }
  };

  useEffect(() => {
    setAuthor(authorFromUrl);
    if (authorFromUrl.trim()) {
      void runSearch(authorFromUrl);
    }
  }, [authorFromUrl, contentLanguage]);

  const handleSubmit = (event: FormEvent) => {
    event.preventDefault();
    const trimmedAuthor = author.trim();
    if (!trimmedAuthor) {
      setError('작가를 입력해 주세요.');
      return;
    }
    setSearchParams({ author: trimmedAuthor });
  };

  const handleAuthorClick = (nextAuthor: string) => {
    setAuthor(nextAuthor);
    setSearchParams({ author: nextAuthor });
  };

  return (
    <div className={styles.page}>
      <form className={styles.toolbar} onSubmit={handleSubmit}>
        <div className={styles.inputWrapper}>
          <Search size={18} className={styles.searchIcon} />
          <input
            className={styles.searchInput}
            type="text"
            value={author}
            onChange={(event) => setAuthor(event.target.value)}
            placeholder="작가명"
            autoComplete="off"
          />
        </div>
        <button type="submit" className={styles.searchButton} disabled={!author.trim() || loading}>
          {loading ? <Loader2 size={18} className={styles.spinIcon} /> : <UsersRound size={18} />}
          {loading ? '검색 중' : '조회'}
        </button>
      </form>

      {error && <div className={styles.error}>{error}</div>}

      {!result && !error && !loading && (
        <div className={styles.empty}>작가를 검색하면 유사 작가와 최신 작품을 보여줍니다.</div>
      )}

      {result && (
        <div className={styles.results}>
          <AuthorGroupSection
            title="검색한 작가"
            group={result.target}
            isTarget
            onAuthorClick={handleAuthorClick}
          />

          <section className={styles.similarSection}>
            <div className={styles.sectionHeader}>
              <h2>유사 작가</h2>
              <span>{result.similarAuthors.length.toLocaleString()}명</span>
            </div>
            <div className={styles.groupList}>
              {result.similarAuthors.length > 0 ? (
                result.similarAuthors.map((group, index) => (
                  <AuthorGroupSection
                    key={group.authorKey}
                    title={`#${index + 1}`}
                    group={group}
                    onAuthorClick={handleAuthorClick}
                  />
                ))
              ) : (
                <div className={styles.empty}>유사 작가 결과가 없습니다.</div>
              )}
            </div>
          </section>
        </div>
      )}
    </div>
  );
}

interface AuthorGroupSectionProps {
  title: string;
  group: AuthorSimilarityGroup;
  isTarget?: boolean;
  onAuthorClick: (author: string) => void;
}

function AuthorGroupSection({ title, group, isTarget = false, onAuthorClick }: AuthorGroupSectionProps) {
  return (
    <section className={isTarget ? styles.targetGroup : styles.authorGroup}>
      <div className={styles.groupHeader}>
        <div className={styles.groupTitle}>
          <span className={styles.groupLabel}>{title}</span>
          <button
            type="button"
            className={styles.authorButton}
            onClick={() => onAuthorClick(group.authorName || group.authorKey)}
          >
            {group.authorName || group.authorKey}
          </button>
        </div>
        <div className={styles.groupMeta}>
          {group.score != null && <span>score {group.score.toFixed(3)}</span>}
          <span>{group.workCount.toLocaleString()}작품</span>
          {group.sharedKeywordCount != null && <span>{group.sharedKeywordCount.toLocaleString()} shared</span>}
        </div>
      </div>

      {group.sharedKeywords && group.sharedKeywords.length > 0 && (
        <div className={styles.keywordRow}>
          {group.sharedKeywords.slice(0, 5).map((keyword) => (
            <span key={keyword.keyword} className={styles.keywordChip}>
              {keyword.keyword}
            </span>
          ))}
        </div>
      )}

      <div className={styles.workGrid}>
        {group.works.length > 0 ? (
          group.works.slice(0, 5).map((article) => (
            <ArticleCard key={article.Id} article={article} />
          ))
        ) : (
          <div className={styles.emptyInline}>최신 작품 없음</div>
        )}
      </div>
    </section>
  );
}
