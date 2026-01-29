/**
 * Constructeur de prompts optimises pour l'IA
 * Genere des prompts systeme et utilisateur contextuels
 */

import logger from '../utils/logger.js';
import ConversationAnalyzer from './conversation-analyzer.js';

/**
 * Classe pour construire des prompts optimises
 */
export class PromptBuilder {
  /**
   * Construit le prompt systeme enrichi
   * @param {string} mode - 'suggest' ou 'improve'
   * @param {string} userName - Nom de l'utilisateur
   * @param {ConversationAnalysis} analysis - Analyse de la conversation
   * @returns {string}
   */
  static buildSystemPrompt(mode, userName, analysis) {
    const basePersonality = this.buildBasePersonality(userName, analysis);
    const missionPrompt = mode === 'suggest'
      ? this.buildSuggestMission(userName, analysis)
      : this.buildImproveMission(userName, analysis);

    return `${basePersonality}\n\n${missionPrompt}`;
  }

  /**
   * Construit la personnalite de base de l'assistant
   */
  static buildBasePersonality(userName, analysis) {
    return `Tu es un assistant IA conversationnel expert qui aide ${userName} a communiquer efficacement.

CONTEXTE DE LA CONVERSATION:
- Ton general: ${analysis.tone}
- Type de relation: ${analysis.relationship}
- Sujets abordes: ${analysis.topics.join(', ')}
- Resume: ${analysis.conversationSummary}
- Ton emotionnel: ${analysis.emotionalTone}
- Flux: ${analysis.conversationFlow}
- Urgence: ${analysis.urgency}
- Formalite: ${Math.round(analysis.formality * 100)}%

EXPERTISE:
- Analyse psychologique des conversations
- Adaptation du ton et du style au contexte
- Communication empathique et naturelle
- Detection des nuances emotionnelles
- Suggestions pertinentes et authentiques`;
  }

  /**
   * Construit la mission pour le mode suggestion
   */
  static buildSuggestMission(userName, analysis) {
    const styleGuidelines = this.getStyleGuidelines(analysis);

    return `MISSION - SUGGESTION DE REPONSE:
Tu dois proposer une reponse que ${userName} peut envoyer directement.

PRINCIPES CLES:
1. AUTHENTICITE: La reponse doit sembler venir naturellement de ${userName}
2. ADAPTATION: Respecte le ton ${analysis.tone} et la relation ${analysis.relationship}
3. PERTINENCE: Reponds en coherence avec les sujets: ${analysis.topics.join(', ')}
4. EMOTION: Maintiens un ton ${analysis.emotionalTone}
5. FLUIDITE: Continue le flux ${analysis.conversationFlow} de la conversation
${analysis.urgency === 'urgent' ? '6. URGENCE: Le contexte semble urgent, sois reactif' : ''}

REGLES ABSOLUES:
- Reponds UNIQUEMENT avec le message suggere (aucune explication)
- Pas de guillemets, pas de preambule, pas de "Voici ma suggestion:"
- 1-3 phrases maximum selon le contexte
- Langage naturel et humain
- En francais
- Ne dis JAMAIS "En tant qu'assistant..." ou formulations similaires
- Adapte la longueur au ton: ${analysis.tone === 'informel' ? 'court et direct' : 'complet mais concis'}

STYLE A ADOPTER:
${styleGuidelines}`;
  }

  /**
   * Construit la mission pour le mode amelioration
   */
  static buildImproveMission(userName, analysis) {
    return `MISSION - AMELIORATION DE MESSAGE:
Tu dois ameliorer le brouillon de ${userName} tout en preservant son intention.

PRINCIPES CLES:
1. FIDELITE: Garde le sens exact du message original
2. AMELIORATION: Rends le message plus clair, fluide et impactant
3. PERSONNALITE: Conserve la voix et le style de ${userName}
4. ADAPTATION: Respecte le ton ${analysis.tone} de la conversation
5. COHERENCE: Assure la continuite avec le ton ${analysis.emotionalTone}

REGLES ABSOLUES:
- Reponds UNIQUEMENT avec le message ameliore (aucune explication)
- Pas de guillemets, pas de commentaires, pas de "Version amelioree:"
- Garde la longueur similaire a l'original (+-20%)
- Corrige les fautes sans changer le sens
- En francais
- Ne change pas radicalement le message
- Preserve les emojis si presents dans l'original`;
  }

  /**
   * Obtient les directives de style basees sur l'analyse
   */
  static getStyleGuidelines(analysis) {
    let guidelines = [];

    // Style selon le ton
    if (analysis.tone === 'formel') {
      guidelines.push('- Utilise un langage poli et professionnel');
      guidelines.push('- Evite les abreviations et le langage familier');
      guidelines.push('- Structure claire et phrases completes');
    } else if (analysis.tone === 'informel') {
      guidelines.push('- Langage decontracte et naturel');
      guidelines.push('- Tu peux utiliser des abreviations courantes (ok, rdv, etc.)');
      guidelines.push('- Sois spontane et direct');
    } else {
      guidelines.push('- Equilibre entre simplicite et politesse');
      guidelines.push('- Ton amical mais respectueux');
    }

    // Style selon la relation
    if (analysis.relationship === 'professionnel') {
      guidelines.push('- Maintiens une distance professionnelle appropriee');
    } else if (analysis.relationship === 'couple') {
      guidelines.push('- Ton affectueux autorise si coherent avec la conversation');
    } else if (analysis.relationship === 'famille') {
      guidelines.push('- Ton chaleureux et familier');
    }

    // Style selon l'emotion
    if (analysis.emotionalTone === 'positif') {
      guidelines.push('- Maintiens l\'energie positive');
    } else if (analysis.emotionalTone === 'negatif') {
      guidelines.push('- Fais preuve d\'empathie et de soutien');
    }

    return guidelines.join('\n');
  }

  /**
   * Construit le prompt utilisateur enrichi
   * @param {string} mode - 'suggest' ou 'improve'
   * @param {string} currentInput - Texte actuel (pour mode improve)
   * @param {Array} messages - Messages de la conversation
   * @param {string} currentUserId - ID de l'utilisateur courant
   * @param {string} currentUserName - Nom de l'utilisateur courant
   * @param {ConversationAnalysis} analysis - Analyse de la conversation
   * @returns {string}
   */
  static buildUserPrompt(mode, currentInput, messages, currentUserId, currentUserName, analysis) {
    const contextMessages = this.buildStructuredContext(messages, currentUserId, currentUserName);

    if (mode === 'suggest') {
      return this.buildSuggestUserPrompt(
        contextMessages, messages, currentUserId, currentUserName, analysis
      );
    }

    return this.buildImproveUserPrompt(
      contextMessages, currentInput, currentUserName, analysis
    );
  }

  /**
   * Construit le contexte structure des messages
   */
  static buildStructuredContext(messages, currentUserId, currentUserName) {
    if (!messages || messages.length === 0) {
      return '[Aucun message precedent - Nouvelle conversation]';
    }

    const lines = [];

    // Si beaucoup de messages, creer des sections
    if (messages.length > 8) {
      const oldMessages = messages.slice(0, messages.length - 6);
      const recentMessages = messages.slice(-6);

      // Resume des anciens messages
      const myCount = oldMessages.filter((m) => m.senderId === currentUserId).length;
      const otherCount = oldMessages.length - myCount;
      const otherName = oldMessages.find((m) => m.senderId !== currentUserId)?.senderName || 'Contact';

      lines.push(`[DEBUT DE CONVERSATION - ${oldMessages.length} messages]`);
      lines.push(`Resume: ${myCount} messages de moi, ${otherCount} de ${otherName}`);
      lines.push('');
      lines.push('[MESSAGES RECENTS]');

      // Messages recents detailles
      recentMessages.forEach((msg, i) => {
        const isMe = msg.senderId === currentUserId;
        const prefix = isMe ? `[MOI] ${currentUserName}` : msg.senderName;
        lines.push(`${i + 1}. ${prefix}: "${msg.content}"`);
      });
    } else {
      // Tous les messages
      messages.forEach((msg, i) => {
        const isMe = msg.senderId === currentUserId;
        const prefix = isMe ? `[MOI] ${currentUserName}` : msg.senderName;
        lines.push(`${i + 1}. ${prefix}: "${msg.content}"`);
      });
    }

    return lines.join('\n');
  }

  /**
   * Construit le prompt utilisateur pour le mode suggestion
   */
  static buildSuggestUserPrompt(contextMessages, messages, currentUserId, currentUserName, analysis) {
    const otherMessages = messages.filter((m) => m.senderId !== currentUserId);

    if (otherMessages.length === 0) {
      return `HISTORIQUE DE LA CONVERSATION:
${contextMessages}

RESUME CONTEXTUEL:
${analysis.conversationSummary}

INFORMATIONS CLES:
- Relation: ${analysis.relationship}
- Ton attendu: ${analysis.tone}
- Ambiance: ${analysis.emotionalTone}

MISSION:
Propose un message pertinent pour que ${currentUserName} ${messages.length === 0 ? 'demarre' : 'relance'} cette conversation de maniere naturelle et engageante.`;
    }

    const lastOther = otherMessages[otherMessages.length - 1];
    const expectedResponse = ConversationAnalyzer.analyzeExpectedResponse(lastOther.content);

    return `HISTORIQUE DE LA CONVERSATION:
${contextMessages}

---

RESUME CONTEXTUEL:
${analysis.conversationSummary}

ANALYSE DU DERNIER MESSAGE:
${lastOther.senderName} a ecrit: "${lastOther.content}"
- Type de message: ${expectedResponse.description}
- Ton utilise: ${analysis.tone}
- Emotion: ${analysis.emotionalTone}

INFORMATIONS CONTEXTUELLES:
- Nombre de messages: ${analysis.messageCount}
- Sujets en cours: ${analysis.topics.join(', ')}
- Flux de conversation: ${analysis.conversationFlow}
- Relation: ${analysis.relationship}

MISSION:
Genere UNE reponse parfaite que ${currentUserName} peut envoyer a ${lastOther.senderName}.
La reponse doit etre naturelle, appropriee au contexte, et reflete la personnalite de ${currentUserName}.`;
  }

  /**
   * Construit le prompt utilisateur pour le mode amelioration
   */
  static buildImproveUserPrompt(contextMessages, currentInput, currentUserName, analysis) {
    return `CONTEXTE DE LA CONVERSATION:
${contextMessages}

---

RESUME:
${analysis.conversationSummary}

ANALYSE DU TON:
- Style actuel: ${analysis.tone}
- Relation: ${analysis.relationship}
- Ambiance: ${analysis.emotionalTone}

BROUILLON DE ${currentUserName}:
"${currentInput}"

MISSION:
Ameliore ce brouillon pour qu'il soit plus fluide, naturel et impactant tout en gardant exactement le meme sens et l'intention de ${currentUserName}.
Respecte le ton ${analysis.tone} et l'ambiance ${analysis.emotionalTone} de la conversation.`;
  }
}

export default PromptBuilder;
