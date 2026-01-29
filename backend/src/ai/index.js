/**
 * Module IA - Exports principaux
 * Point d'entree unique pour tous les services d'intelligence artificielle
 */

export { AIService, aiService } from './ai-service.js';
export { ConversationAnalyzer, ConversationAnalysis } from './conversation-analyzer.js';
export { PromptBuilder } from './prompt-builder.js';

// Export par defaut du service IA
import aiService from './ai-service.js';
export default aiService;
