/**
 * Routes API pour les services d'intelligence artificielle
 */

import { Router } from 'express';
import aiService from '../ai/index.js';
import { asyncHandler, Errors } from '../middleware/error-handler.js';
import {
  validateSuggestionRequest,
  validateAnalyzeRequest,
} from '../middleware/validate-request.js';
import logger from '../utils/logger.js';

const router = Router();

/**
 * POST /api/ai/suggest
 * Genere une suggestion de message basee sur le contexte de conversation
 *
 * Body:
 * - currentInput: string (optionnel) - Texte actuel du champ de saisie
 * - messages: Array - Messages de la conversation
 * - currentUserId: string - ID de l'utilisateur courant
 * - currentUserName: string - Nom de l'utilisateur courant
 *
 * Response:
 * - suggestion: string - Le message suggere
 * - mode: 'suggest' | 'improve' - Le mode utilise
 * - analysis: object - Analyse de la conversation
 * - metadata: object - Informations sur le traitement
 */
router.post(
  '/suggest',
  validateSuggestionRequest,
  asyncHandler(async (req, res) => {
    const { currentInput, messages, currentUserId, currentUserName } = req.body;

    logger.info('Requete de suggestion recue', {
      userId: currentUserId,
      userName: currentUserName,
      messageCount: messages?.length || 0,
      hasInput: !!currentInput,
    });

    if (!aiService.isAvailable()) {
      throw Errors.AIServiceError('Service IA temporairement indisponible');
    }

    const result = await aiService.generateSuggestion({
      currentInput: currentInput || '',
      messages: messages || [],
      currentUserId,
      currentUserName,
    });

    res.json({
      success: true,
      data: result,
    });
  })
);

/**
 * POST /api/ai/analyze
 * Analyse une conversation sans generer de suggestion
 *
 * Body:
 * - messages: Array - Messages de la conversation
 * - currentUserId: string - ID de l'utilisateur courant
 * - currentUserName: string (optionnel) - Nom de l'utilisateur
 *
 * Response:
 * - analysis: object - Analyse complete de la conversation
 */
router.post(
  '/analyze',
  validateAnalyzeRequest,
  asyncHandler(async (req, res) => {
    const { messages, currentUserId, currentUserName } = req.body;

    logger.info('Requete d\'analyse recue', {
      userId: currentUserId,
      messageCount: messages.length,
    });

    const analysis = aiService.analyzeConversation(
      messages,
      currentUserId,
      currentUserName || 'Utilisateur'
    );

    res.json({
      success: true,
      data: { analysis },
    });
  })
);

/**
 * GET /api/ai/status
 * Verifie le statut du service IA
 *
 * Response:
 * - available: boolean - Si le service est disponible
 * - model: string - Le modele utilise
 */
router.get('/status', (req, res) => {
  res.json({
    success: true,
    data: {
      available: aiService.isAvailable(),
      model: aiService.isAvailable() ? 'llama-3.1-8b-instant' : null,
      timestamp: new Date().toISOString(),
    },
  });
});

/**
 * POST /api/ai/suggest-multiple
 * Genere plusieurs suggestions alternatives
 *
 * Body: (meme que /suggest)
 * - count: number (optionnel) - Nombre de suggestions (max 5, default 3)
 *
 * Response:
 * - suggestions: Array<string> - Liste de suggestions
 */
router.post(
  '/suggest-multiple',
  validateSuggestionRequest,
  asyncHandler(async (req, res) => {
    const { currentInput, messages, currentUserId, currentUserName, count = 3 } = req.body;

    if (!aiService.isAvailable()) {
      throw Errors.AIServiceError('Service IA temporairement indisponible');
    }

    const maxCount = Math.min(Math.max(1, parseInt(count, 10) || 3), 5);

    const suggestions = await aiService.generateMultipleSuggestions(
      {
        currentInput: currentInput || '',
        messages: messages || [],
        currentUserId,
        currentUserName,
      },
      maxCount
    );

    res.json({
      success: true,
      data: { suggestions },
    });
  })
);

export default router;
