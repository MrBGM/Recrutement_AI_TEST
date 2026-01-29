/**
 * Routes de sante et monitoring
 */

import { Router } from 'express';
import aiService from '../ai/index.js';

const router = Router();

/**
 * GET /health
 * Endpoint de verification de sante du serveur
 */
router.get('/', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    services: {
      ai: aiService.isAvailable() ? 'available' : 'unavailable',
    },
  });
});

/**
 * GET /health/ready
 * Verification de disponibilite (pour load balancers)
 */
router.get('/ready', (req, res) => {
  const isReady = aiService.isAvailable();

  if (isReady) {
    res.json({ status: 'ready' });
  } else {
    res.status(503).json({ status: 'not ready', reason: 'AI service unavailable' });
  }
});

/**
 * GET /health/live
 * Verification de vivacite (pour kubernetes)
 */
router.get('/live', (req, res) => {
  res.json({ status: 'alive' });
});

export default router;
