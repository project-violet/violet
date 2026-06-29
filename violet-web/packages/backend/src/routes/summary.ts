import { Router } from 'express';
import { readFile } from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SUMMARY_DIR = path.resolve(__dirname, '../../../../../violet-search/summary');

export const summaryRouter = Router();

summaryRouter.get('/:articleId', async (req, res) => {
  const articleId = req.params.articleId;

  if (!/^\d+$/.test(articleId)) {
    res.status(400).json({ error: 'Invalid article ID.' });
    return;
  }

  try {
    const filePath = path.join(SUMMARY_DIR, `${articleId}.txt`);
    const content = await readFile(filePath, 'utf-8');
    res.json({ articleId, content });
  } catch {
    res.status(404).json({ error: 'Summary not found.' });
  }
});
