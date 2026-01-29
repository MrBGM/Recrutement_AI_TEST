/**
 * Middleware de gestion des erreurs
 * Centralise le traitement des erreurs de l'API
 */

import logger from '../utils/logger.js';

/**
 * Classe d'erreur API personnalisee
 */
export class APIError extends Error {
  constructor(message, statusCode = 500, code = 'INTERNAL_ERROR') {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.isOperational = true;

    Error.captureStackTrace(this, this.constructor);
  }
}

/**
 * Erreurs predefinies
 */
export const Errors = {
  BadRequest: (message = 'Requete invalide') => new APIError(message, 400, 'BAD_REQUEST'),
  Unauthorized: (message = 'Non autorise') => new APIError(message, 401, 'UNAUTHORIZED'),
  Forbidden: (message = 'Acces interdit') => new APIError(message, 403, 'FORBIDDEN'),
  NotFound: (message = 'Ressource non trouvee') => new APIError(message, 404, 'NOT_FOUND'),
  RateLimited: (message = 'Trop de requetes') => new APIError(message, 429, 'RATE_LIMITED'),
  AIServiceError: (message = 'Erreur du service IA') => new APIError(message, 503, 'AI_SERVICE_ERROR'),
};

/**
 * Middleware de gestion des erreurs
 */
export function errorHandler(err, req, res, next) {
  // Log de l'erreur
  if (err.isOperational) {
    logger.warn('Erreur operationnelle', {
      code: err.code,
      message: err.message,
      path: req.path,
    });
  } else {
    logger.error('Erreur inattendue', {
      error: err.message,
      stack: err.stack,
      path: req.path,
    });
  }

  // Determiner le code de statut
  const statusCode = err.statusCode || 500;

  // Construire la reponse
  const response = {
    success: false,
    error: {
      code: err.code || 'INTERNAL_ERROR',
      message: err.isOperational ? err.message : 'Une erreur interne est survenue',
    },
  };

  // En dev, inclure plus de details
  if (process.env.NODE_ENV !== 'production') {
    response.error.stack = err.stack;
  }

  res.status(statusCode).json(response);
}

/**
 * Middleware pour les routes non trouvees
 */
export function notFoundHandler(req, res, next) {
  next(Errors.NotFound(`Route ${req.method} ${req.path} non trouvee`));
}

/**
 * Wrapper async pour les routes
 * Capture automatiquement les erreurs des fonctions async
 */
export function asyncHandler(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

export default errorHandler;
