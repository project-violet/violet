import { Router } from 'express';
import { getUserDb } from '../services/user-db.js';
import { getUserActivity } from '../services/user-activity.js';

export const activityRouter = Router();

activityRouter.get('/', (_req, res) => {
  res.json(getUserActivity(getUserDb()));
});
