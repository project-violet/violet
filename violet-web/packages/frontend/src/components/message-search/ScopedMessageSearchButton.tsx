import { useCallback, useEffect, useId, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { useLocation, useNavigate } from 'react-router';
import { useTranslation } from 'react-i18next';
import { MessageSquareText, X } from 'lucide-react';
import type { MessageSearchMode } from '@violet-web/shared';
import { getCompletedDownloadIds } from '../../api/downloads';
import { useAppStore } from '../../stores/app-store';
import { MessageSearchPanel } from './MessageSearchPanel';
import styles from './ScopedMessageSearchDialog.module.css';
import { useDialogScrollRestoration } from '../../hooks/useDialogScrollRestoration';

interface Props {
  articleIds: number[];
  label: string;
  disabled?: boolean;
  completedOnly?: boolean;
}

export function ScopedMessageSearchButton({ articleIds, label, disabled, completedOnly }: Props) {
  const { t } = useTranslation();
  const enabled = useAppStore((s) => s.messageSearchEnabled);
  const location = useLocation();
  const navigate = useNavigate();
  const params = new URLSearchParams(location.search);
  const scopeId = params.get('messageScope');
  const snapshot = useMemo(() => {
    if (!scopeId) return undefined;
    try {
      const value = sessionStorage.getItem(`messageScope:${scopeId}`);
      return value ? JSON.parse(value) as { ids: number[]; label: string } : undefined;
    } catch { return undefined; }
  }, [scopeId]);
  const scope = snapshot ? { ...snapshot, query: params.get('messageQ') || '', mode: (params.get('messageMode') === 'similar' ? 'similar' : 'contains') as MessageSearchMode } : undefined;
  const setScope = useCallback((next: typeof scope, replace = false) => {
    const nextParams = new URLSearchParams(location.search);
    if (next) {
      // getRandomValues also works on plain HTTP LAN/Tailscale origins.
      const id = nextParams.get('messageScope') || Array.from(
        crypto.getRandomValues(new Uint8Array(16)),
        (byte) => byte.toString(16).padStart(2, '0'),
      ).join('');
      sessionStorage.setItem(`messageScope:${id}`, JSON.stringify({ ids: next.ids, label: next.label }));
      nextParams.set('messageScope', id);
      nextParams.set('messageQ', next.query);
      nextParams.set('messageMode', next.mode);
    } else {
      nextParams.delete('messageScope'); nextParams.delete('messageQ'); nextParams.delete('messageMode');
    }
    navigate({ pathname: location.pathname, search: nextParams.toString(), hash: location.hash }, { replace, state: location.state });
  }, [navigate, location]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const buttonRef = useRef<HTMLButtonElement>(null);
  const close = useCallback(() => { setScope(undefined, true); buttonRef.current?.focus(); }, [setScope]);
  const open = async () => {
    setBusy(true); setError('');
    // Snapshot before any await: later list updates must not change this search.
    let ids = [...new Set(articleIds)].sort((a, b) => a - b);
    const scopeLabel = label;
    try {
      if (completedOnly) {
        const completed = new Set(await getCompletedDownloadIds());
        ids = ids.filter((id) => completed.has(id));
      }
      if (ids.length > 50_000) { setError(t('scopedMessageSearch.tooLarge')); return; }
      setScope({ ids, label: scopeLabel, query: '', mode: 'contains' });
    } catch { setError(t('scopedMessageSearch.loadError')); }
    finally { setBusy(false); }
  };
  return <>
    <button ref={buttonRef} className={styles.openButton} type="button" disabled={disabled || busy || !enabled} onClick={open}>
      <MessageSquareText size={16} />{t(busy ? 'scopedMessageSearch.preparing' : 'scopedMessageSearch.open')}
    </button>
    {error && <span role="alert" className={styles.error}>{error}</span>}
    {scope && <ScopedMessageSearchDialog ids={scope.ids} label={scope.label} search={scope} onSearch={(query, mode) => setScope({ ...scope, query, mode })} onClose={close} />}
  </>;
}

export function ScopedMessageSearchDialog({ ids, label, search, onSearch, onClose }: { ids: number[]; label: string; search: { query: string; mode: MessageSearchMode }; onSearch: (query: string, mode: MessageSearchMode) => void; onClose: () => void }) {
  const { t } = useTranslation();
  const titleId = useId();
  const dialogRef = useRef<HTMLDivElement>(null);
  const bodyRef = useRef<HTMLDivElement>(null);
  useDialogScrollRestoration(bodyRef);
  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null;
    dialogRef.current?.querySelector<HTMLInputElement>('input[type="text"]')?.focus({ preventScroll: true });
    const content = document.querySelector<HTMLElement>('main');
    const oldOverflow = content?.style.overflow;
    if (content) content.style.overflow = 'hidden';
    return () => {
      if (content) content.style.overflow = oldOverflow ?? '';
      if (previous?.isConnected) previous.focus();
    };
  }, []);
  return createPortal(<div className={styles.overlay} onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
    <div ref={dialogRef} className={styles.dialog} role="dialog" aria-modal="true" aria-labelledby={titleId}
      onKeyDown={(event) => {
        event.stopPropagation();
        if (event.key === 'Escape' && !event.defaultPrevented) { event.preventDefault(); onClose(); }
        if (event.key === 'Tab') {
          const items = Array.from(dialogRef.current!.querySelectorAll<HTMLElement>('button:not(:disabled),input:not(:disabled),select:not(:disabled),a[href],[tabindex="0"]')).filter((el) => el.getClientRects().length);
          const first = items[0], last = items.at(-1);
          if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last?.focus(); }
          else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus(); }
        }
      }}>
      <header className={styles.header}>
        <div><h2 id={titleId}>{t('scopedMessageSearch.title', { scope: label })}</h2>
          <p>{t('scopedMessageSearch.scopeCount', { count: ids.length, formattedCount: ids.length.toLocaleString() })}</p></div>
        <button type="button" onClick={onClose} aria-label={t('scopedMessageSearch.close')}><X size={22} /></button>
      </header>
      <div ref={bodyRef} className={styles.body} data-message-search-scroll>
        <MessageSearchPanel query={search.query} mode={search.mode} articleIds={ids}
          onSearch={onSearch} />
      </div>
    </div>
  </div>, document.body);
}
