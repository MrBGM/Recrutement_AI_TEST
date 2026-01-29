/**
 * Service principal d'intelligence artificielle
 * Gere les appels a l'API Groq et la generation de suggestions
 */

import Groq from 'groq-sdk';
import config from '../config/index.js';
import logger from '../utils/logger.js';
import ConversationAnalyzer from './conversation-analyzer.js';
import PromptBuilder from './prompt-builder.js';

/**
 * Service IA pour la generation de suggestions
 */
export class AIService {
  constructor() {
    this.groq = null;
    this.isInitialized = false;
    this.initializeGroq();
  }

  /**
   * Initialise le client Groq
   */
  initializeGroq() {
    if (!config.groq.apiKey) {
      logger.warn('Cle API Groq non configuree - Le service IA sera limite');
      return;
    }

    try {
      this.groq = new Groq({
        apiKey: config.groq.apiKey,
      });
      this.isInitialized = true;
      logger.info('Service IA initialise avec succes');
    } catch (error) {
      logger.error('Erreur lors de l\'initialisation du service IA', { error });
    }
  }

  /**
   * Verifie si le service est disponible
   */
  isAvailable() {
    return this.isInitialized && this.groq !== null;
  }

  /**
   * Genere une suggestion de message
   * @param {Object} params - Parametres de generation
   * @param {string} params.currentInput - Texte actuel (vide = suggest, rempli = improve)
   * @param {Array} params.messages - Messages de la conversation
   * @param {string} params.currentUserId - ID de l'utilisateur courant
   * @param {string} params.currentUserName - Nom de l'utilisateur courant
   * @returns {Promise<Object>} - Suggestion et metadonnees
   */
  async generateSuggestion({ currentInput, messages, currentUserId, currentUserName }) {
    if (!this.isAvailable()) {
      throw new Error('Service IA non disponible - Verifiez la configuration');
    }

    const startTime = Date.now();
    const mode = currentInput?.trim() ? 'improve' : 'suggest';

    logger.info('Generation de suggestion', {
      mode,
      messageCount: messages?.length || 0,
      userName: currentUserName,
    });

    try {
      // Analyser la conversation
      const analysis = ConversationAnalyzer.analyze(
        messages || [],
        currentUserId,
        currentUserName
      );

      // Construire les prompts
      const systemPrompt = PromptBuilder.buildSystemPrompt(mode, currentUserName, analysis);
      const userPrompt = PromptBuilder.buildUserPrompt(
        mode,
        currentInput || '',
        messages || [],
        currentUserId,
        currentUserName,
        analysis
      );

      // Appeler l'API Groq
      const completion = await this.groq.chat.completions.create({
        model: config.ai.model,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
        max_tokens: config.ai.maxTokens,
        temperature: config.ai.temperature,
      });

      const suggestion = completion.choices[0]?.message?.content?.trim() || '';
      const processingTime = Date.now() - startTime;

      // Nettoyer la suggestion (enlever les guillemets si presents)
      const cleanedSuggestion = this.cleanSuggestion(suggestion);

      logger.info('Suggestion generee avec succes', {
        mode,
        processingTime: `${processingTime}ms`,
        tokensUsed: completion.usage?.total_tokens,
      });

      return {
        suggestion: cleanedSuggestion,
        mode,
        analysis: analysis.toJSON(),
        metadata: {
          model: config.ai.model,
          processingTime,
          tokensUsed: completion.usage?.total_tokens,
        },
      };
    } catch (error) {
      logger.error('Erreur lors de la generation de suggestion', {
        error: error.message,
        mode,
      });
      throw error;
    }
  }

  /**
   * Nettoie la suggestion des artefacts non desires
   */
  cleanSuggestion(suggestion) {
    if (!suggestion) return '';

    let cleaned = suggestion;

    // Enlever les guillemets au debut et a la fin
    cleaned = cleaned.replace(/^["']|["']$/g, '');

    // Enlever les prefixes courants non desires
    const prefixesToRemove = [
      /^Voici ma suggestion\s*:\s*/i,
      /^Suggestion\s*:\s*/i,
      /^Reponse\s*:\s*/i,
      /^Message\s*:\s*/i,
      /^Version amelioree\s*:\s*/i,
    ];

    for (const prefix of prefixesToRemove) {
      cleaned = cleaned.replace(prefix, '');
    }

    return cleaned.trim();
  }

  /**
   * Genere plusieurs suggestions alternatives
   * @param {Object} params - Parametres de generation
   * @param {number} count - Nombre de suggestions a generer
   * @returns {Promise<Array>} - Liste de suggestions
   */
  async generateMultipleSuggestions(params, count = 3) {
    const suggestions = [];

    for (let i = 0; i < count; i++) {
      try {
        // Augmenter legerement la temperature pour la variete
        const originalTemp = config.ai.temperature;
        config.ai.temperature = Math.min(1, originalTemp + (i * 0.1));

        const result = await this.generateSuggestion(params);
        suggestions.push(result.suggestion);

        config.ai.temperature = originalTemp;
      } catch (error) {
        logger.warn(`Erreur generation suggestion ${i + 1}`, { error: error.message });
      }
    }

    // Dedupliquer
    return [...new Set(suggestions)];
  }

  /**
   * Analyse une conversation sans generer de suggestion
   * @param {Array} messages - Messages de la conversation
   * @param {string} currentUserId - ID de l'utilisateur courant
   * @param {string} currentUserName - Nom de l'utilisateur courant
   * @returns {Object} - Analyse de la conversation
   */
  analyzeConversation(messages, currentUserId, currentUserName) {
    const analysis = ConversationAnalyzer.analyze(messages, currentUserId, currentUserName);
    return analysis.toJSON();
  }
}

// Export d'une instance singleton
export const aiService = new AIService();

export default aiService;