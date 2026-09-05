import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import type { Response } from 'express';

/**
 * Proxy an image from a remote URL, setting appropriate headers (Referer, etc.)
 * to bypass CORS and hotlink protection.
 */
export async function proxyImage(
  url: string,
  referer: string | undefined,
  res: Response,
): Promise<void> {
  const headers: Record<string, string> = {
    'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
  };

  if (referer) {
    headers['Referer'] = referer;
  }

  // Rewrite dead hitomi.la subdomains to gold-usergeneratedcontent.net
  const rewritten = url.replace(
    /^(https?:\/\/)([a-z]+)\.hitomi\.la\//,
    (_, proto, sub) => `${proto}${sub}.gold-usergeneratedcontent.net/`,
  );

  const controller = new AbortController();
  const onClose = () => controller.abort();
  res.once('close', onClose);
  try {
    const upstream = await fetch(rewritten, { headers, signal: controller.signal });

    if (!upstream.ok) {
      await upstream.body?.cancel();
      res.status(upstream.status).json({ error: `Upstream returned ${upstream.status}` });
      return;
    }

    const contentType = upstream.headers.get('content-type');
    if (contentType) {
      res.setHeader('Content-Type', contentType);
    }

    const contentLength = upstream.headers.get('content-length');
    if (contentLength) {
      res.setHeader('Content-Length', contentLength);
    }

    res.setHeader('Cache-Control', 'public, max-age=86400');

    if (upstream.body) {
      await pipeline(Readable.fromWeb(upstream.body as Parameters<typeof Readable.fromWeb>[0]), res);
    } else {
      res.end();
    }
  } finally {
    res.off('close', onClose);
  }
}
