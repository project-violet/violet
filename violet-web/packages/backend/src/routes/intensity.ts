import { Router } from 'express';
import { getIntensityTimelineStore } from '../services/intensity-timelines.js';

export const intensityRouter = Router();

intensityRouter.get('/status', async (_req, res) => {
  const status = await getIntensityTimelineStore().status();
  res.status(status.available ? 200 : 503).json(status);
});

intensityRouter.get('/:workId', async (req, res) => {
  const workId = Number(req.params.workId);
  if (!Number.isSafeInteger(workId) || workId <= 0) {
    res.status(400).json({ error: 'Invalid work id.' });
    return;
  }

  try {
    const timeline = await getIntensityTimelineStore().get(workId);
    if (!timeline) {
      res.status(404).json({ error: 'Intensity timeline not found.' });
      return;
    }
    res.json(timeline);
  } catch (error) {
    console.error('Intensity timeline error:', error);
    res.status(503).json({
      error: error instanceof Error ? error.message : 'Intensity timeline unavailable.',
    });
  }
});
