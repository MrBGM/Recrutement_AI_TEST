/**
 * Analyseur de conversation intelligent
 * Extrait le contexte, le ton, les sujets et les emotions d'une conversation
 */

import logger from '../utils/logger.js';

/**
 * Classe representant l'analyse d'une conversation
 */
export class ConversationAnalysis {
  constructor({
    tone = 'neutre',
    relationship = 'inconnu',
    topics = [],
    conversationSummary = '',
    messageCount = 0,
    lastSpeaker = '',
    conversationFlow = 'debut',
    emotionalTone = 'neutre',
    urgency = 'normal',
    formality = 0.5,
  } = {}) {
    this.tone = tone;
    this.relationship = relationship;
    this.topics = topics;
    this.conversationSummary = conversationSummary;
    this.messageCount = messageCount;
    this.lastSpeaker = lastSpeaker;
    this.conversationFlow = conversationFlow;
    this.emotionalTone = emotionalTone;
    this.urgency = urgency;
    this.formality = formality; // 0 = tres informel, 1 = tres formel
  }

  toJSON() {
    return {
      tone: this.tone,
      relationship: this.relationship,
      topics: this.topics,
      conversationSummary: this.conversationSummary,
      messageCount: this.messageCount,
      lastSpeaker: this.lastSpeaker,
      conversationFlow: this.conversationFlow,
      emotionalTone: this.emotionalTone,
      urgency: this.urgency,
      formality: this.formality,
    };
  }
}

/**
 * Analyseur de conversation
 */
export class ConversationAnalyzer {
  // Dictionnaires de detection
  static FORMAL_INDICATORS = [
    'bonjour', 'bonsoir', 'merci', 'cordialement', 'sincèrement',
    'pourriez', 'veuillez', 'je vous prie', 'permettez', 'monsieur',
    'madame', 'respectueusement', 'bien à vous', 'salutations',
  ];

  static INFORMAL_INDICATORS = [
    'salut', 'coucou', 'ouais', 'cool', 'lol', 'mdr', 'ptdr',
    'tkt', 'jsp', 'wsh', 'bg', 'oklm', 'yo', 'hey', 'cc',
    'tranquille', 'grave', 'trop', 'genre', 'quoi', 'nan',
  ];

  static POSITIVE_INDICATORS = [
    'content', 'super', 'génial', 'cool', 'parfait', 'merci',
    'top', 'excellent', 'bravo', 'magnifique', 'incroyable',
    'heureux', 'ravi', 'adorable', 'formidable', 'chouette',
  ];

  static NEGATIVE_INDICATORS = [
    'désolé', 'dommage', 'problème', 'malheureusement', 'triste',
    'inquiet', 'stressé', 'difficile', 'compliqué', 'ennuyeux',
    'frustrant', 'décevant', 'mauvais', 'terrible', 'horrible',
  ];

  static POSITIVE_EMOJIS = ['😊', '😂', '😄', '😃', '🙂', '❤️', '💕', '👍', '🎉', '✨', '🥳', '😁', '🤗', '💪', '👏'];
  static NEGATIVE_EMOJIS = ['😢', '😔', '😡', '💔', '😤', '😞', '😟', '😰', '😭', '🙁', '😕', '😣'];

  static TOPIC_KEYWORDS = {
    travail: ['travail', 'projet', 'réunion', 'bureau', 'chef', 'collègue', 'deadline', 'meeting', 'boss', 'boulot', 'job'],
    'rendez-vous': ['rdv', 'rendez-vous', 'voir', 'rencontrer', 'heure', 'demain', 'ce soir', 'samedi', 'dimanche', 'week-end'],
    loisirs: ['film', 'série', 'jeu', 'sport', 'musique', 'concert', 'soirée', 'sortie', 'resto', 'bar'],
    nourriture: ['manger', 'restaurant', 'bouffe', 'dîner', 'déjeuner', 'petit-dej', 'café', 'boire', 'faim'],
    voyage: ['voyage', 'vacances', 'partir', 'destination', 'avion', 'train', 'hôtel', 'plage', 'montagne'],
    famille: ['famille', 'parents', 'maman', 'papa', 'frère', 'soeur', 'enfants', 'bébé', 'mariage'],
    santé: ['santé', 'médecin', 'malade', 'hôpital', 'docteur', 'fatigue', 'repos', 'dormir'],
    argent: ['argent', 'payer', 'prix', 'cher', 'budget', 'économies', 'acheter', 'vendre'],
  };

  static URGENCY_INDICATORS = {
    high: ['urgent', 'vite', 'rapidement', 'asap', 'immédiatement', 'maintenant', 'tout de suite', 'dépêche'],
    low: ['quand tu peux', 'pas pressé', 'tranquille', 'à l\'occasion', 'un jour'],
  };

  /**
   * Analyse une conversation complete
   * @param {Array} messages - Liste des messages
   * @param {string} currentUserId - ID de l'utilisateur courant
   * @param {string} currentUserName - Nom de l'utilisateur courant
   * @returns {ConversationAnalysis}
   */
  static analyze(messages, currentUserId, currentUserName) {
    if (!messages || messages.length === 0) {
      logger.debug('Analyse: Conversation vide');
      return new ConversationAnalysis({
        conversationSummary: 'Nouvelle conversation',
      });
    }

    try {
      const tone = this.detectTone(messages);
      const relationship = this.detectRelationship(messages, tone);
      const topics = this.extractTopics(messages);
      const emotionalTone = this.detectEmotionalTone(messages);
      const conversationFlow = this.analyzeConversationFlow(messages, currentUserId);
      const summary = this.createConversationSummary(messages, currentUserId, topics);
      const urgency = this.detectUrgency(messages);
      const formality = this.calculateFormality(messages);

      const lastMessage = messages[messages.length - 1];
      const lastSpeaker = lastMessage.senderId === currentUserId ? 'moi' : lastMessage.senderName;

      const analysis = new ConversationAnalysis({
        tone,
        relationship,
        topics,
        conversationSummary: summary,
        messageCount: messages.length,
        lastSpeaker,
        conversationFlow,
        emotionalTone,
        urgency,
        formality,
      });

      logger.debug('Analyse terminee', { analysis: analysis.toJSON() });
      return analysis;
    } catch (error) {
      logger.error('Erreur lors de l\'analyse de conversation', { error });
      return new ConversationAnalysis();
    }
  }

  /**
   * Detecte le ton general de la conversation
   */
  static detectTone(messages) {
    let formalScore = 0;
    let informalScore = 0;

    const allContent = messages.map((m) => m.content.toLowerCase()).join(' ');

    for (const word of this.FORMAL_INDICATORS) {
      const regex = new RegExp(`\\b${word}\\b`, 'gi');
      const matches = allContent.match(regex);
      if (matches) formalScore += matches.length;
    }

    for (const word of this.INFORMAL_INDICATORS) {
      const regex = new RegExp(`\\b${word}\\b`, 'gi');
      const matches = allContent.match(regex);
      if (matches) informalScore += matches.length * 1.5; // Poids plus fort pour l'informel
    }

    if (formalScore > informalScore * 2) return 'formel';
    if (informalScore > formalScore) return 'informel';
    return 'neutre';
  }

  /**
   * Detecte le type de relation entre les interlocuteurs
   */
  static detectRelationship(messages, tone) {
    const content = messages.map((m) => m.content.toLowerCase()).join(' ');

    if (tone === 'formel') return 'professionnel';

    // Detecter les indices de relation
    if (/\b(patron|chef|manager|directeur|client)\b/i.test(content)) {
      return 'professionnel';
    }
    if (/\b(maman|papa|famille|parents?|frère|soeur)\b/i.test(content)) {
      return 'famille';
    }
    if (/\b(collègue|bureau|travail|réunion|projet)\b/i.test(content)) {
      return 'collegue';
    }
    if (/\b(chéri|bébé|mon amour|ma puce|mon coeur)\b/i.test(content)) {
      return 'couple';
    }

    return 'ami';
  }

  /**
   * Extrait les sujets principaux de la conversation
   */
  static extractTopics(messages) {
    const topics = [];
    const content = messages.map((m) => m.content.toLowerCase()).join(' ');

    for (const [topic, keywords] of Object.entries(this.TOPIC_KEYWORDS)) {
      const hasKeyword = keywords.some((keyword) => content.includes(keyword));
      if (hasKeyword) {
        topics.push(topic);
      }
    }

    return topics.length > 0 ? topics : ['discussion generale'];
  }

  /**
   * Detecte le ton emotionnel de la conversation
   */
  static detectEmotionalTone(messages) {
    let positiveScore = 0;
    let negativeScore = 0;

    const allContent = messages.map((m) => m.content).join(' ');
    const contentLower = allContent.toLowerCase();

    // Analyser les mots
    for (const word of this.POSITIVE_INDICATORS) {
      if (contentLower.includes(word)) positiveScore++;
    }
    for (const word of this.NEGATIVE_INDICATORS) {
      if (contentLower.includes(word)) negativeScore++;
    }

    // Analyser les emojis (poids double)
    for (const emoji of this.POSITIVE_EMOJIS) {
      const count = (allContent.match(new RegExp(emoji, 'g')) || []).length;
      positiveScore += count * 2;
    }
    for (const emoji of this.NEGATIVE_EMOJIS) {
      const count = (allContent.match(new RegExp(emoji, 'g')) || []).length;
      negativeScore += count * 2;
    }

    // Points d'exclamation = positif
    const exclamations = (allContent.match(/!/g) || []).length;
    positiveScore += Math.min(exclamations, 3);

    if (positiveScore > negativeScore * 1.5) return 'positif';
    if (negativeScore > positiveScore) return 'negatif';
    return 'neutre';
  }

  /**
   * Analyse le flux de la conversation
   */
  static analyzeConversationFlow(messages, currentUserId) {
    if (messages.length < 2) return 'debut';

    const recentMessages = messages.slice(-5);
    let questionCount = 0;
    let myMessages = 0;

    for (const msg of recentMessages) {
      if (msg.content.includes('?')) questionCount++;
      if (msg.senderId === currentUserId) myMessages++;
    }

    if (questionCount >= 2) return 'interrogatif';
    if (myMessages >= 3) return 'actif';
    if (messages.length > 20) return 'prolonge';

    return 'fluide';
  }

  /**
   * Cree un resume intelligent de la conversation
   */
  static createConversationSummary(messages, currentUserId, topics) {
    if (messages.length === 0) return 'Nouvelle conversation';

    const otherMessages = messages.filter((m) => m.senderId !== currentUserId);
    let summary = '';

    // Type de conversation
    if (messages.length <= 3) {
      summary = 'Debut de conversation';
    } else if (messages.length <= 10) {
      summary = 'Conversation en cours';
    } else if (messages.length <= 30) {
      summary = 'Discussion active';
    } else {
      summary = 'Longue discussion';
    }

    // Ajouter les sujets
    if (topics.length > 0 && topics[0] !== 'discussion generale') {
      summary += ` portant sur ${topics.slice(0, 2).join(' et ')}`;
    }

    // Analyser le dernier message de l'autre
    if (otherMessages.length > 0) {
      const lastOther = otherMessages[otherMessages.length - 1].content;
      if (lastOther.includes('?')) {
        summary += '. Question en attente de reponse';
      } else if (lastOther.endsWith('!')) {
        summary += '. Message enthousiaste recu';
      }
    }

    return summary;
  }

  /**
   * Detecte le niveau d'urgence
   */
  static detectUrgency(messages) {
    const recentContent = messages.slice(-3).map((m) => m.content.toLowerCase()).join(' ');

    for (const word of this.URGENCY_INDICATORS.high) {
      if (recentContent.includes(word)) return 'urgent';
    }
    for (const word of this.URGENCY_INDICATORS.low) {
      if (recentContent.includes(word)) return 'faible';
    }

    return 'normal';
  }

  /**
   * Calcule un score de formalite (0-1)
   */
  static calculateFormality(messages) {
    let formalScore = 0;
    let informalScore = 0;

    const allContent = messages.map((m) => m.content.toLowerCase()).join(' ');

    for (const word of this.FORMAL_INDICATORS) {
      if (allContent.includes(word)) formalScore++;
    }
    for (const word of this.INFORMAL_INDICATORS) {
      if (allContent.includes(word)) informalScore++;
    }

    const total = formalScore + informalScore;
    if (total === 0) return 0.5;

    return formalScore / total;
  }

  /**
   * Analyse ce qui est attendu comme reponse
   */
  static analyzeExpectedResponse(message) {
    const lower = message.toLowerCase();

    if (message.includes('?')) {
      if (/\b(quand|quelle heure|à quelle)\b/i.test(lower)) {
        return { type: 'temporelle', description: 'Question temporelle - necessite une date/heure' };
      }
      if (/\b(où|quel endroit|quel lieu)\b/i.test(lower)) {
        return { type: 'lieu', description: 'Question de lieu - necessite une localisation' };
      }
      if (/\b(comment|pourquoi|explique)\b/i.test(lower)) {
        return { type: 'explicative', description: 'Question explicative - necessite des details' };
      }
      if (/\b(tu veux|on fait|ça te dit)\b/i.test(lower)) {
        return { type: 'proposition', description: 'Proposition - necessite acceptation/refus' };
      }
      return { type: 'ouverte', description: 'Question ouverte - necessite une reponse informative' };
    }

    if (message.endsWith('!')) {
      return { type: 'exclamation', description: 'Exclamation - reaction enthousiaste possible' };
    }

    if (/\b(ok|d'accord|parfait|super|bien)\b/i.test(lower)) {
      return { type: 'validation', description: 'Validation - peut clore le sujet ou continuer' };
    }

    return { type: 'affirmation', description: 'Affirmation - reponse contextuelle appropriee' };
  }
}

export default ConversationAnalyzer;
