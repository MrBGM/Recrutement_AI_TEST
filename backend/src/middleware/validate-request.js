/**
 * Middleware de validation des requetes
 * Valide les donnees entrantes pour les endpoints IA
 */

import { Errors } from './error-handler.js';

/**
 * Schema de validation pour la generation de suggestion
 */
const suggestionSchema = {
  currentInput: { type: 'string', required: false, maxLength: 2000 },
  messages: { type: 'array', required: false, maxItems: 50 },
  currentUserId: { type: 'string', required: true, minLength: 1 },
  currentUserName: { type: 'string', required: true, minLength: 1, maxLength: 100 },
};

/**
 * Valide un message individuel
 */
function validateMessage(msg, index) {
  const errors = [];

  if (!msg || typeof msg !== 'object') {
    errors.push(`messages[${index}]: doit etre un objet`);
    return errors;
  }

  if (!msg.content || typeof msg.content !== 'string') {
    errors.push(`messages[${index}].content: requis et doit etre une chaine`);
  } else if (msg.content.length > 5000) {
    errors.push(`messages[${index}].content: trop long (max 5000 caracteres)`);
  }

  if (!msg.senderId || typeof msg.senderId !== 'string') {
    errors.push(`messages[${index}].senderId: requis et doit etre une chaine`);
  }

  if (!msg.senderName || typeof msg.senderName !== 'string') {
    errors.push(`messages[${index}].senderName: requis et doit etre une chaine`);
  }

  return errors;
}

/**
 * Middleware de validation pour l'endpoint de suggestion
 */
export function validateSuggestionRequest(req, res, next) {
  const errors = [];
  const body = req.body;

  // Valider currentUserId
  if (!body.currentUserId || typeof body.currentUserId !== 'string') {
    errors.push('currentUserId: requis et doit etre une chaine');
  }

  // Valider currentUserName
  if (!body.currentUserName || typeof body.currentUserName !== 'string') {
    errors.push('currentUserName: requis et doit etre une chaine');
  } else if (body.currentUserName.length > 100) {
    errors.push('currentUserName: trop long (max 100 caracteres)');
  }

  // Valider currentInput (optionnel)
  if (body.currentInput !== undefined) {
    if (typeof body.currentInput !== 'string') {
      errors.push('currentInput: doit etre une chaine');
    } else if (body.currentInput.length > 2000) {
      errors.push('currentInput: trop long (max 2000 caracteres)');
    }
  }

  // Valider messages (optionnel)
  if (body.messages !== undefined) {
    if (!Array.isArray(body.messages)) {
      errors.push('messages: doit etre un tableau');
    } else if (body.messages.length > 50) {
      errors.push('messages: trop de messages (max 50)');
    } else {
      // Valider chaque message
      body.messages.forEach((msg, index) => {
        errors.push(...validateMessage(msg, index));
      });
    }
  }

  if (errors.length > 0) {
    return next(Errors.BadRequest(`Validation echouee: ${errors.join('; ')}`));
  }

  next();
}

/**
 * Middleware de validation pour l'analyse de conversation
 */
export function validateAnalyzeRequest(req, res, next) {
  const errors = [];
  const body = req.body;

  // Valider messages (requis)
  if (!body.messages || !Array.isArray(body.messages)) {
    errors.push('messages: requis et doit etre un tableau');
  } else if (body.messages.length === 0) {
    errors.push('messages: au moins un message requis');
  } else if (body.messages.length > 100) {
    errors.push('messages: trop de messages (max 100)');
  } else {
    body.messages.forEach((msg, index) => {
      errors.push(...validateMessage(msg, index));
    });
  }

  // Valider currentUserId
  if (!body.currentUserId || typeof body.currentUserId !== 'string') {
    errors.push('currentUserId: requis et doit etre une chaine');
  }

  // Valider currentUserName (optionnel)
  if (body.currentUserName !== undefined && typeof body.currentUserName !== 'string') {
    errors.push('currentUserName: doit etre une chaine');
  }

  if (errors.length > 0) {
    return next(Errors.BadRequest(`Validation echouee: ${errors.join('; ')}`));
  }

  next();
}

export default { validateSuggestionRequest, validateAnalyzeRequest };
