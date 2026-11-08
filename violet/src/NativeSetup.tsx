import { useEffect, useState } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { open } from '@tauri-apps/plugin-dialog';
import { t } from './i18n';
import './native.css';

export interface Status {
  status: string;
  stage?: 'extracting' | 'validating' | 'indexing' | null;
  dbExists: boolean;
  lastSync: string | null;
  error: string | null;
  progress?: { current: number; total: number; message: string } | null;
}

export function NativeSetup({ onReady }: { onReady: () => void }) {
  const [status, setStatus] = useState<Status>();
  const [error, setError] = useState('');
  const [starting, setStarting] = useState(false);
  const busy = starting || !!status && ['checking', 'downloading_full', 'building_cache'].includes(status.status);
  useEffect(() => {
    let mounted = true;
    const refresh = () => invoke<Status>('native_status').then(value => {
      if (mounted) setStatus(value);
    }).catch(e => { if (mounted) setError(String(e)); });
    void refresh();
    const timer = setInterval(refresh, 1000);
    return () => { mounted = false; clearInterval(timer); };
  }, []);

  async function start(importFile: boolean) {
    setError('');
    setStarting(true);
    try {
      if (importFile) {
        const path = await open({ multiple: false, directory: false, filters: [{ name: 'SQLite / ZIP', extensions: ['db', 'sqlite', 'sqlite3', 'zip'] }] });
        if (!path) return;
        await invoke('native_import', { path });
      } else {
        await invoke('native_sync');
      }
      setStatus(await invoke<Status>('native_status'));
    } catch (e) { setError(String(e)); }
    finally { setStarting(false); }
  }

  return <main className="native-setup">
    <section className="native-card">
      <img src="/logos/logo.png" alt="Violet" width="72" height="72" />
      <h1>{t('title')}</h1>
      <p>{t('description')}</p>
      <p className="native-note">{t('source')}</p>
      <div className="native-actions">
        <button className="native-primary" disabled={busy} onClick={() => void start(false)}>{t('download')}</button>
        <button disabled={busy} onClick={() => void start(true)}>{t('import')}</button>
      </div>
      {busy && <div role="status"><p>{t(status?.stage ?? 'working')}</p><progress max={status?.progress?.total || undefined} value={status?.progress?.current || undefined} /><p>{status?.progress?.message}</p></div>}
      {(error || status?.error) && <div role="alert"><strong>{t('error')}</strong><pre>{error || status?.error}</pre></div>}
      {status?.dbExists && !busy && <button className="native-primary" onClick={onReady}>{t('ready')}</button>}
      <p className="native-note">{t('privacy')}</p>
      <p className="native-note">{t('note')}</p>
    </section>
  </main>;
}
