/**
 * Configuration centralisee du backend
 * Charge les variables d'environnement et exporte la configuration
 */

import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

// Charger les variables d'environnement
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
dotenv.config({ path: join(__dirname, '../../.env') });

export const config = {
  // Serveur
  port: parseInt(process.env.PORT, 10) || 3001,
  nodeEnv: process.env.NODE_ENV || 'development',
  isProduction: process.env.NODE_ENV === 'production',

  // API Groq
  groq: {
    apiKey: process.env.GROQ_API_KEY,
    baseUrl: 'https://api.groq.com/openai/v1/chat/completions',
  },

  // Configuration IA (alignée avec le frontend)
  ai: {
    primaryModel: process.env.AI_MODEL || 'llama-3.1-70b-versatile',
    fallbackModel: process.env.AI_FALLBACK_MODEL || 'llama-3.1-8b-instant',
    maxTokens: parseInt(process.env.AI_MAX_TOKENS, 10) || 250,
    temperature: parseFloat(process.env.AI_TEMPERATURE) || 0.7,
    topP: parseFloat(process.env.AI_TOP_P) || 0.9,
    presencePenalty: parseFloat(process.env.AI_PRESENCE_PENALTY) || 0.1,
  },

  // Firebase
  firebase: {
    projectId: process.env.FIREBASE_PROJECT_ID || 'ai-chat-23aa5',
  },

  // Rate Limiting
  rateLimit: {
    windowMs: 60 * 1000, // 1 minute
    maxRequests: 30, // 30 requetes par minute
  },

  // CORS
cors: {
  origins: process.env.CORS_ORIGINS?.split(',') || [
    'https://ai-chat-23aa5.web.app',
    'https://ai-chat-23aa5.firebaseapp.com',
    'http://localhost:3000',
    'http://localhost:8080',
    'http://127.0.0.1:3000',
    'http://127.0.0.1:8080'
  ],
},
};

/**
 * Valide que toutes les variables requises sont presentes
 */
export function validateConfig() {
  const required = ['GROQ_API_KEY'];
  const missing = required.filter((key) => !process.env[key]);

  if (missing.length > 0) {
    console.warn(`[CONFIG] Variables manquantes: ${missing.join(', ')}`);
    console.warn('[CONFIG] Certaines fonctionnalites peuvent ne pas fonctionner');
  }

  return missing.length === 0;
}

export default config;  // ← AJOUTEZ CETTE LIGNE