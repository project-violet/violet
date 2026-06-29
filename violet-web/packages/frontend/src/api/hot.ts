export type HotPeriod = 'daily' | 'weekly' | 'monthly' | 'alltime';

interface HotViewResponse {
  elements: { articleId: number; count: number }[];
}

async function computeVValid(salt: string, token: string): Promise<string> {
  const input = salt.replace(/\\/g, '') + token;
  const encoded = new TextEncoder().encode(input);
  const hashBuffer = await crypto.subtle.digest('SHA-512', encoded);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hex = hashArray.map((b) => b.toString(16).padStart(2, '0')).join('');
  return hex.slice(0, 7);
}

export async function fetchHotView(
  serverHost: string,
  salt: string,
  period: HotPeriod,
  offset: number,
  count: number,
): Promise<{ elements: { articleId: number; count: number }[] }> {
  const token = Date.now().toString();
  const valid = await computeVValid(salt, token);

  const url = `${serverHost}/api/v2/view?offset=${offset}&count=${count}&type=${period}`;
  const res = await fetch(url, {
    headers: {
      'v-token': token,
      'v-valid': valid,
    },
  });

  if (!res.ok) {
    throw new Error(`Hot API error: ${res.status}`);
  }

  const data: HotViewResponse = await res.json();
  return { elements: data.elements };
}
