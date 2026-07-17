import path from 'path';
import express from 'express';
import cors from 'cors';
import { contentRouter } from './routes/content.js';
import { proxyRouter } from './routes/proxy.js';
import { bookmarksRouter } from './routes/bookmarks.js';
import { historyRouter } from './routes/history.js';
import { syncRouter } from './routes/sync.js';
import { downloadsRouter } from './routes/downloads.js';
import { aiSearchRouter } from './routes/ai-search.js';
import { messageSearchRouter } from './routes/message-search.js';
import { llmSearchRouter } from './routes/llm-search.js';
import { workExperimentRouter } from './routes/work-experiment.js';
import { authorSimilarityRouter } from './routes/author-similarity.js';
import { summaryRouter } from './routes/summary.js';
import { activityRouter } from './routes/activity.js';
import { errorHandler } from './middleware/error-handler.js';
import { requestLogger } from './middleware/request-logger.js';

export function createApp() {
  const app = express();

  app.use(cors());
  app.use(express.json());
  app.use(requestLogger);

  app.get('/api/health', (_req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
  });

  app.use('/api/content', contentRouter);
  app.use('/api/proxy', proxyRouter);
  app.use('/api/bookmarks', bookmarksRouter);
  app.use('/api/history', historyRouter);
  app.use('/api/sync', syncRouter);
  app.use('/api/downloads', downloadsRouter);
  app.use('/api/ai-search', aiSearchRouter);
  app.use('/api/message-search', messageSearchRouter);
  app.use('/api/llm-search', llmSearchRouter);
  app.use('/api/work-experiment', workExperimentRouter);
  app.use('/api/author-similarity', authorSimilarityRouter);
  app.use('/api/summary', summaryRouter);
  app.use('/api/activity', activityRouter);

  app.use(errorHandler);

  // Serve frontend static files in production
  const frontendDist = process.env.FRONTEND_DIST;
  if (frontendDist) {
    const distPath = path.resolve(frontendDist);
    app.use(express.static(distPath));

    // SPA catch-all: non-API routes return index.html
    app.get('{*path}', (_req, res) => {
      res.sendFile(path.join(distPath, 'index.html'));
    });

    console.log(`[violet-web] Serving frontend from ${distPath}`);
  }

  return app;
}
