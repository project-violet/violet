import { Router } from 'express';
import { SyncManager } from '../services/sync-manager.js';

export const syncRouter = Router();

// GET /api/sync/status - Get current sync status
syncRouter.get('/status', (req, res) => {
  try {
    const syncManager = SyncManager.getInstance();
    const status = syncManager.getStatus();
    res.json(status);
  } catch (error) {
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

// POST /api/sync/trigger - Trigger chunk sync
syncRouter.post('/trigger', (req, res) => {
  try {
    const syncManager = SyncManager.getInstance();

    // Run sync in background
    syncManager.checkAndSync().catch((err) => {
      console.error('[sync/trigger] Background sync error:', err);
    });

    // Return immediately with 202 Accepted
    res.status(202).json({
      message: 'Sync triggered, check /api/sync/status for progress',
    });
  } catch (error) {
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

// POST /api/sync/full - Trigger full DB re-download
syncRouter.post('/full', (req, res) => {
  try {
    const syncManager = SyncManager.getInstance();

    // Run full sync in background
    syncManager.triggerFullSync().catch((err) => {
      console.error('[sync/full] Background full sync error:', err);
    });

    // Return immediately with 202 Accepted
    res.status(202).json({
      message: 'Full sync triggered, check /api/sync/status for progress',
    });
  } catch (error) {
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});
