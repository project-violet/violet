import { AxiosError, AxiosHeaders, CanceledError, type AxiosAdapter } from 'axios';

export interface Request {
  method: string;
  path: string;
  params: Record<string, string>;
  body: Record<string, unknown>;
}

export class BackendError extends Error {
  constructor(public status: number, message: string) { super(message); }
}

export function createAdapter(dispatch: (request: Request) => Promise<unknown>): AxiosAdapter {
  return async (config) => {
    if (config.signal?.aborted) throw new CanceledError();
    const url = new URL(config.url ?? '/', 'https://violet.invalid');
    const params = Object.fromEntries(url.searchParams);
    for (const [key, value] of Object.entries(config.params ?? {})) {
      if (value !== undefined && value !== null) params[key] = String(value);
    }
    let body: Record<string, unknown> = {};
    if (config.data) body = typeof config.data === 'string' ? JSON.parse(config.data) : config.data;
    let timer: ReturnType<typeof setTimeout> | undefined;
    let abort: (() => void) | undefined;
    try {
      const data = await Promise.race([
        dispatch({ method: (config.method ?? 'get').toUpperCase(), path: url.pathname.replace(/\/$/, '') || '/', params, body }),
        new Promise<never>((_, reject) => {
          abort = () => reject(new CanceledError());
          config.signal?.addEventListener?.('abort', abort);
          if (config.timeout) timer = setTimeout(() => reject(new AxiosError('Native request timed out', 'ECONNABORTED', config)), config.timeout);
        }),
      ]);
      return { data, status: 200, statusText: 'OK', headers: new AxiosHeaders(), config };
    } catch (error) {
      if (error instanceof AxiosError) throw error;
      const status = error instanceof BackendError ? error.status : 500;
      const message = error instanceof Error ? error.message : String(error);
      throw new AxiosError(message, 'ERR_BAD_RESPONSE', config, undefined, {
        data: { error: message }, status, statusText: message, headers: new AxiosHeaders(), config,
      });
    } finally {
      clearTimeout(timer);
      if (abort) config.signal?.removeEventListener?.('abort', abort);
    }
  };
}
