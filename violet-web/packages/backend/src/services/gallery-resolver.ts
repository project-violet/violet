/**
 * Ported from violet/lib/script/script_manager.dart
 *
 * Resolves a hitomi gallery ID into image URLs by:
 * 1. Fetching the V3/V4 script from project-violet/scripts
 * 2. Evaluating gg.js for CDN routing
 * 3. Running hitomi_get_image_list() to extract URLs
 *
 * Uses Node.js vm module instead of flutter_js.
 */

import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import vm from 'node:vm';
import type { ImageList } from '@violet-web/shared';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SCRIPT_V3_MODEL_PATH = path.resolve(__dirname, '../../scripts/hitomi_get_image_list_v3_model.js');
const SCRIPT_V4_URL =
  'https://github.com/project-violet/scripts/raw/main/hitomi_get_image_list_v4_model.js';
const GG_JS_URL = 'https://ltn.gold-usergeneratedcontent.net/gg.js';

const USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

let scriptCache: string | null = null;
let latestUpdate = 0;

async function fetchText(url: string, headers?: Record<string, string>): Promise<string> {
  const res = await fetch(url, {
    headers: { 'User-Agent': USER_AGENT, ...headers },
  });
  if (!res.ok) throw new Error(`Failed to fetch ${url}: ${res.status}`);
  return res.text();
}

function parseGg(ggBody: string): { ggM: string; ggB: string; ggS: string } {
  const ggContext = vm.createContext({});
  // Remove 'use strict' as it prevents gg instance resolution
  const ggCode = ggBody.split("'use strict';")[1] || ggBody;
  vm.runInContext(ggCode, ggContext);

  const ggM = vm.runInContext(
    `var r = ""; for (var i = 0; i < 4096; i++) { r += gg.m(i).toString() + ","; } r`,
    ggContext,
  ) as string;

  const ggB = vm.runInContext('gg.b', ggContext) as string;
  const ggS = vm.runInContext('gg.s.toString()', ggContext) as string;

  return { ggM, ggB, ggS };
}

async function tryRefreshV4(): Promise<boolean> {
  try {
    const ggBody = await fetchText(GG_JS_URL);
    const { ggM, ggB } = parseGg(ggBody);
    let v4Script = await fetchText(SCRIPT_V4_URL);
    v4Script = v4Script.replaceAll('%%gg.m%', ggM).replaceAll('%%gg.b%', ggB);

    scriptCache = v4Script;
    latestUpdate = Date.now();
    return true;
  } catch {
    return false;
  }
}

async function tryRefreshV3Model(): Promise<boolean> {
  try {
    const ggBody = await fetchText(GG_JS_URL);
    const { ggM, ggB, ggS } = parseGg(ggBody);

    let v3Script = fs.readFileSync(SCRIPT_V3_MODEL_PATH, 'utf-8');
    v3Script = v3Script
      .replaceAll('%%gg.m%', ggM)
      .replaceAll('%%gg.b%', ggB)
      .replaceAll('%%gg.s%', ggS);

    scriptCache = v3Script;
    latestUpdate = Date.now();
    return true;
  } catch {
    return false;
  }
}

async function ensureScript(): Promise<void> {
  // Refresh if cache is empty or older than 30 minutes
  if (scriptCache && Date.now() - latestUpdate < 30 * 60 * 1000) {
    return;
  }

  // Try V4 first, then V3 model as fallback
  if (await tryRefreshV4()) return;
  if (await tryRefreshV3Model()) return;

  throw new Error('Failed to load both V4 and V3 scripts');
}

export async function resolveGallery(id: number): Promise<ImageList> {
  await ensureScript();
  if (!scriptCache) throw new Error('Script not available');

  const context = vm.createContext({
    fetch: globalThis.fetch,
    document: { title: '' },
    window: { innerWidth: 1 },
  });
  vm.runInContext(scriptCache, context);

  // Get download URL
  const downloadUrl = vm.runInContext(
    `create_download_url('${id}')`,
    context,
  ) as string;

  // Get headers for the gallery info request
  const headersJson = vm.runInContext(
    `hitomi_get_header_content('${id}')`,
    context,
  ) as string;
  const headers = JSON.parse(headersJson) as Record<string, string>;
  headers['User-Agent'] = USER_AGENT;

  // Fetch gallery info
  const galleryInfo = await fetchText(downloadUrl, headers);

  // Evaluate gallery info and extract image list
  vm.runInContext(galleryInfo, context);
  const resultJson = vm.runInContext('hitomi_get_image_list()', context) as string;
  const result = JSON.parse(resultJson) as {
    result: string[];
    btresult: string[];
    stresult: string[];
  };

  return {
    urls: result.result,
    bigThumbnails: result.btresult,
    smallThumbnails: result.stresult,
  };
}

/**
 * Get headers required for fetching images from a gallery.
 */
export async function getGalleryHeaders(
  id: string,
): Promise<Record<string, string>> {
  await ensureScript();
  if (!scriptCache) return {};

  const context = vm.createContext({
    document: { title: '' },
    window: { innerWidth: 1 },
  });
  vm.runInContext(scriptCache, context);

  const headersJson = vm.runInContext(
    `hitomi_get_header_content('${id}')`,
    context,
  ) as string;

  return JSON.parse(headersJson) as Record<string, string>;
}
