import { Router } from 'express';

export const aiSearchRouter = Router();

aiSearchRouter.get('/', async (req, res) => {
  const q = (req.query.q as string) || '';
  const topK = parseInt(req.query.top_k as string) || 5;
  const mode = (req.query.mode as string) || 'fast';

  if (!q.trim()) {
    res.status(400).json({ error: 'Query parameter "q" is required.' });
    return;
  }

  try {
    const url = `http://localhost:8787/search?q=${encodeURIComponent(q)}&top_k=${topK}&mode=${encodeURIComponent(mode)}`;
    const response = await fetch(url);

    if (!response.ok) {
      res.status(response.status).json({ error: `Search server returned ${response.status}` });
      return;
    }

    const data = await response.json();
    res.json(data);
  } catch (error) {
    console.error('AI search proxy error:', error);
    res.status(502).json({ error: 'Failed to reach AI search server.' });
  }
});
