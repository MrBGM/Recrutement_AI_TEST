import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import '../config/api_config.dart';
import '../config/api_keys.dart';

/// Service d'intelligence artificielle
/// Gere les appels au backend pour la generation de suggestions
class AIService {
  // Cache pour eviter les appels repetes
  static final Map<String, _CachedAnalysis> _analysisCache = {};
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Modeles AI disponibles (avec fallback)
  static const String _primaryModel = 'llama-3.1-70b-versatile';
  static const String _fallbackModel = 'llama-3.1-8b-instant';

  // Parametres optimises pour la generation
  static const double _temperature = 0.7;
  static const int _maxTokens = 250;
  static const double _topP = 0.9;
  static const double _presencePenalty = 0.1;

  // Nombre de messages de contexte
  static const int _contextMessageLimit = 15;

  /// Genere une suggestion de message
  Future<String> generateSuggestion({
    required String currentInput,
    required List<Message> recentMessages,
    required String currentUserId,
    required String currentUserName,
    bool isGroupChat = false,
    String? groupName,
  }) async {
    try {
      // Essayer d'abord le backend
      final result = await _callBackend(
        currentInput: currentInput,
        recentMessages: recentMessages,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        isGroupChat: isGroupChat,
        groupName: groupName,
      );
      return result;
    } catch (e) {
      _debugLog('❌ Erreur backend: $e');

      // En cas d'erreur, utiliser le fallback si configure
      if (ApiConfig.enableFallback && ApiKeys.isGroqConfigured) {
        _debugLog('🔄 Utilisation du fallback Groq direct');
        return _callGroqDirectly(
          currentInput: currentInput,
          recentMessages: recentMessages,
          currentUserId: currentUserId,
          currentUserName: currentUserName,
          isGroupChat: isGroupChat,
          groupName: groupName,
        );
      }

      // Si pas de fallback, renvoyer une erreur claire
      throw Exception(
          'Backend indisponible. Vérifiez que le serveur tourne sur ${ApiConfig.backendUrl}');
    }
  }

  /// Appelle le backend pour generer une suggestion
  Future<String> _callBackend({
    required String currentInput,
    required List<Message> recentMessages,
    required String currentUserId,
    required String currentUserName,
    bool isGroupChat = false,
    String? groupName,
  }) async {
    final url = ApiConfig.suggestUrl;
    _debugLog('🌐 Appel backend: $url');

    final body = jsonEncode({
      'currentInput': currentInput,
      'messages': recentMessages
          .map((m) => {
                'content': m.content,
                'senderId': m.senderId,
                'senderName': m.senderName,
              })
          .toList(),
      'currentUserId': currentUserId,
      'currentUserName': currentUserName,
      'isGroupChat': isGroupChat,
      'groupName': groupName,
    });

    _debugLog('📦 Messages envoyés: ${recentMessages.length}');

    try {
      final response = await http
          .post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body,
      )
          .timeout(
        Duration(seconds: ApiConfig.receiveTimeout),
        onTimeout: () {
          throw Exception(
              'Timeout: Le serveur ne répond pas (>${ApiConfig.receiveTimeout}s)');
        },
      );

      _debugLog('📡 Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final suggestion = data['data']['suggestion']?.trim() ?? '';
          _debugLog(
              '✅ Suggestion reçue: ${suggestion.substring(0, suggestion.length > 50 ? 50 : suggestion.length)}...');
          return suggestion;
        }
        throw Exception('Réponse invalide du serveur');
      } else {
        final error = jsonDecode(response.body);
        final errorMsg =
            error['error']?['message'] ?? 'Erreur API: ${response.statusCode}';
        _debugLog('❌ Erreur API: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      _debugLog('❌ Exception: $e');
      rethrow;
    }
  }

  /// Appel direct a l'API Groq (fallback)
  Future<String> _callGroqDirectly({
    required String currentInput,
    required List<Message> recentMessages,
    required String currentUserId,
    required String currentUserName,
    bool isGroupChat = false,
    String? groupName,
  }) async {
    const baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
    final mode = currentInput.isEmpty ? 'suggest' : 'improve';

    _debugLog('🤖 Appel Groq direct - Mode: $mode, Groupe: $isGroupChat');

    // Analyser la conversation
    final analysis = _analyzeConversation(
      recentMessages,
      currentUserId,
      currentUserName,
      isGroupChat: isGroupChat,
      groupName: groupName,
    );

    // Construire les prompts
    final systemPrompt = _buildSystemPrompt(
      mode,
      currentUserName,
      analysis,
      isGroupChat: isGroupChat,
      groupName: groupName,
    );
    final userPrompt = _buildUserPrompt(
      mode,
      currentInput,
      recentMessages,
      currentUserId,
      currentUserName,
      analysis,
      isGroupChat: isGroupChat,
      groupName: groupName,
    );

    try {
      // Essayer d'abord avec le modele principal
      final response = await _tryGroqModel(
        baseUrl: baseUrl,
        model: _primaryModel,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      );

      if (response != null) {
        return response;
      }

      // Fallback vers le modele secondaire
      _debugLog('🔄 Fallback vers $_fallbackModel');
      final fallbackResponse = await _tryGroqModel(
        baseUrl: baseUrl,
        model: _fallbackModel,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      );

      if (fallbackResponse != null) {
        return fallbackResponse;
      }

      throw Exception('Les deux modèles IA sont indisponibles');
    } catch (e) {
      _debugLog('❌ Erreur Groq: $e');
      rethrow;
    }
  }

  /// Essaie d'appeler un modele Groq specifique
  Future<String?> _tryGroqModel({
    required String baseUrl,
    required String model,
    required String systemPrompt,
    required String userPrompt,
  }) async {
    try {
      _debugLog('🤖 Tentative avec modèle: $model');

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ApiKeys.groqApiKey}',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'max_tokens': _maxTokens,
          'temperature': _temperature,
          'top_p': _topP,
          'presence_penalty': _presencePenalty,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final suggestion =
            data['choices'][0]['message']['content']?.trim() ?? '';
        _debugLog('✅ Groq ($model): Suggestion générée');
        return suggestion;
      } else {
        _debugLog('⚠️ Modèle $model erreur: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _debugLog('⚠️ Exception modèle $model: $e');
      return null;
    }
  }

  /// Verifie si le backend est disponible
  Future<bool> isBackendAvailable() async {
    try {
      _debugLog('🔍 Test de disponibilité backend...');
      final response = await http
          .get(Uri.parse(ApiConfig.statusUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final available = data['data']?['available'] == true;
        _debugLog(
            available ? '✅ Backend disponible' : '❌ Backend indisponible');
        return available;
      }
      _debugLog('❌ Backend status code: ${response.statusCode}');
      return false;
    } catch (e) {
      _debugLog('❌ Backend non accessible: $e');
      return false;
    }
  }

  /// Log de debug
  void _debugLog(String message) {
    if (ApiConfig.debugMode) {
      print('[AIService] $message');
    }
  }

  /// Analyse une conversation
  _ConversationAnalysis _analyzeConversation(
    List<Message> messages,
    String currentUserId,
    String currentUserName, {
    bool isGroupChat = false,
    String? groupName,
  }) {
    // Verifier le cache
    final cacheKey = '${currentUserId}_${messages.length}_$isGroupChat';
    final cached = _analysisCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.timestamp) < _cacheDuration) {
      return cached.analysis;
    }

    if (messages.isEmpty) {
      return _ConversationAnalysis(
        tone: 'neutre',
        relationship: isGroupChat ? 'groupe' : 'inconnu',
        topics: ['discussion generale'],
        conversationSummary: isGroupChat
            ? 'Nouvelle conversation de groupe'
            : 'Nouvelle conversation',
        messageCount: 0,
        lastSpeaker: '',
        conversationFlow: 'debut',
        emotionalTone: 'neutre',
        participants: [],
        isGroupChat: isGroupChat,
        groupName: groupName,
        urgency: 'basse',
        pendingQuestions: [],
        rhythm: 'modere',
        averageMessageLength: 0.0,
        timeOfDay: _detectTimeOfDay(),
        detectedIntentions: [],
        contactStyle: 'neutre',
      );
    }

    // Identifier les participants uniques
    final participants = _identifyParticipants(messages, currentUserId);

    final tone = _detectTone(messages);
    final relationship = isGroupChat
        ? _detectGroupRelationship(messages, participants)
        : _detectRelationship(messages, tone);
    final topics = _extractTopics(messages);
    final emotionalTone = _detectEmotionalTone(messages);
    final conversationFlow = _analyzeConversationFlow(messages, currentUserId);
    final summary = _createConversationSummary(
      messages,
      currentUserId,
      topics,
      isGroupChat: isGroupChat,
      participants: participants,
    );

    final lastMessage = messages.last;
    final lastSpeaker =
        lastMessage.senderId == currentUserId ? 'moi' : lastMessage.senderName;

    // Nouvelles analyses enrichies
    final urgency = _detectUrgency(messages);
    final pendingQuestions = _extractPendingQuestions(messages, currentUserId);
    final rhythm = _detectRhythm(messages);
    final avgLength = _calculateAverageMessageLength(messages);
    final timeOfDay = _detectTimeOfDay();
    final intentions = _detectIntentions(messages);
    final contactStyle = _detectContactStyle(messages, currentUserId);

    final analysis = _ConversationAnalysis(
      tone: tone,
      relationship: relationship,
      topics: topics,
      conversationSummary: summary,
      messageCount: messages.length,
      lastSpeaker: lastSpeaker,
      conversationFlow: conversationFlow,
      emotionalTone: emotionalTone,
      participants: participants,
      isGroupChat: isGroupChat,
      groupName: groupName,
      urgency: urgency,
      pendingQuestions: pendingQuestions,
      rhythm: rhythm,
      averageMessageLength: avgLength,
      timeOfDay: timeOfDay,
      detectedIntentions: intentions,
      contactStyle: contactStyle,
    );

    // Mettre en cache
    _analysisCache[cacheKey] = _CachedAnalysis(analysis, DateTime.now());

    return analysis;
  }

  /// Identifie les participants uniques dans une conversation
  List<String> _identifyParticipants(
      List<Message> messages, String currentUserId) {
    final participants = <String>{};
    for (final msg in messages) {
      if (msg.senderId != currentUserId) {
        participants.add(msg.senderName);
      }
    }
    return participants.toList();
  }

  String _detectTone(List<Message> messages) {
    int formalScore = 0;
    int informalScore = 0;

    const formalWords = [
      'bonjour',
      'bonsoir',
      'merci',
      'cordialement',
      'pourriez',
      'veuillez',
      'sincèrement'
    ];
    const informalWords = [
      'salut',
      'coucou',
      'ouais',
      'cool',
      'lol',
      'mdr',
      'ptdr',
      'tkt',
      'yo',
      'hey'
    ];

    for (final msg in messages) {
      final content = msg.content.toLowerCase();
      for (final word in formalWords) {
        if (content.contains(word)) formalScore++;
      }
      for (final word in informalWords) {
        if (content.contains(word)) informalScore++;
      }
    }

    if (formalScore > informalScore * 2) return 'formel';
    if (informalScore > formalScore) return 'informel';
    return 'neutre';
  }

  String _detectRelationship(List<Message> messages, String tone) {
    if (tone == 'formel') return 'professionnel';

    final content = messages.map((m) => m.content.toLowerCase()).join(' ');

    if (RegExp(r'\b(travail|projet|réunion|bureau|chef)\b').hasMatch(content)) {
      return 'collegue';
    }
    if (RegExp(r'\b(maman|papa|famille|parents?|frère|soeur)\b')
        .hasMatch(content)) {
      return 'famille';
    }
    if (RegExp(r'\b(chéri|bébé|mon amour|ma puce)\b').hasMatch(content)) {
      return 'couple';
    }

    return 'ami';
  }

  /// Detecte le type de relation dans un groupe
  String _detectGroupRelationship(
      List<Message> messages, List<String> participants) {
    final content = messages.map((m) => m.content.toLowerCase()).join(' ');

    if (RegExp(r'\b(travail|projet|réunion|bureau|deadline|task)\b')
        .hasMatch(content)) {
      return 'groupe_travail';
    }
    if (RegExp(r'\b(famille|fête|anniversaire|noel|vacances)\b')
        .hasMatch(content)) {
      return 'groupe_famille';
    }
    if (RegExp(r'\b(sortie|soirée|bar|restaurant|ciné|match)\b')
        .hasMatch(content)) {
      return 'groupe_amis';
    }
    if (participants.length > 5) {
      return 'grand_groupe';
    }

    return 'groupe_mixte';
  }

  List<String> _extractTopics(List<Message> messages) {
    final topics = <String>[];
    final content = messages.map((m) => m.content.toLowerCase()).join(' ');

    final topicKeywords = {
      'travail': [
        'travail',
        'projet',
        'réunion',
        'bureau',
        'meeting',
        'boulot'
      ],
      'rendez-vous': [
        'rdv',
        'rendez-vous',
        'voir',
        'rencontrer',
        'heure',
        'demain'
      ],
      'loisirs': ['film', 'série', 'jeu', 'sport', 'musique', 'concert'],
      'nourriture': ['manger', 'restaurant', 'bouffe', 'dîner', 'déjeuner'],
      'voyage': ['voyage', 'vacances', 'partir', 'destination', 'avion'],
      'organisation': [
        'organiser',
        'planifier',
        'prévoir',
        'quand',
        'où',
        'qui'
      ],
    };

    topicKeywords.forEach((topic, keywords) {
      if (keywords.any((keyword) => content.contains(keyword))) {
        topics.add(topic);
      }
    });

    return topics.isEmpty ? ['discussion generale'] : topics;
  }

  String _detectEmotionalTone(List<Message> messages) {
    int positiveScore = 0;
    int negativeScore = 0;

    final allContent = messages.map((m) => m.content).join(' ');
    final contentLower = allContent.toLowerCase();

    const positiveWords = [
      'content',
      'super',
      'génial',
      'cool',
      'parfait',
      'merci',
      'top',
      'excellent'
    ];
    const negativeWords = [
      'désolé',
      'dommage',
      'problème',
      'malheureusement',
      'triste',
      'difficile'
    ];
    const positiveEmojis = [
      '😊',
      '😂',
      '😄',
      '❤️',
      '👍',
      '🎉',
      '✨',
      '🥳',
      '😁'
    ];
    const negativeEmojis = ['😢', '😔', '😡', '💔', '😤', '😞', '😭'];

    for (final word in positiveWords) {
      if (contentLower.contains(word)) positiveScore++;
    }
    for (final word in negativeWords) {
      if (contentLower.contains(word)) negativeScore++;
    }
    for (final emoji in positiveEmojis) {
      if (allContent.contains(emoji)) positiveScore += 2;
    }
    for (final emoji in negativeEmojis) {
      if (allContent.contains(emoji)) negativeScore += 2;
    }

    if (positiveScore > negativeScore * 1.5) return 'positif';
    if (negativeScore > positiveScore) return 'negatif';
    return 'neutre';
  }

  String _analyzeConversationFlow(
      List<Message> messages, String currentUserId) {
    if (messages.length < 2) return 'debut';

    final recentMessages =
        messages.length > 5 ? messages.sublist(messages.length - 5) : messages;
    int questionCount = 0;
    int myMessages = 0;

    for (final msg in recentMessages) {
      if (msg.content.contains('?')) questionCount++;
      if (msg.senderId == currentUserId) myMessages++;
    }

    if (questionCount >= 2) return 'interrogatif';
    if (myMessages >= 3) return 'actif';
    return 'fluide';
  }

  /// Detecte le niveau d'urgence dans la conversation
  String _detectUrgency(List<Message> messages) {
    if (messages.isEmpty) return 'basse';

    final recentContent = messages
        .take(5)
        .map((m) => m.content.toLowerCase())
        .join(' ');

    // Mots indiquant une haute urgence
    const highUrgencyWords = [
      'urgent',
      'asap',
      'immediatement',
      'tout de suite',
      'vite',
      'rapidement',
      'important',
      'critique',
      'deadline',
      'maintenant',
      '!!!',
      'sos',
      'aide',
      'help',
    ];

    // Mots indiquant une urgence moyenne
    const mediumUrgencyWords = [
      'bientot',
      'demain',
      'ce soir',
      'cette semaine',
      'des que possible',
      'quand tu peux',
      'a confirmer',
    ];

    for (final word in highUrgencyWords) {
      if (recentContent.contains(word)) return 'haute';
    }

    for (final word in mediumUrgencyWords) {
      if (recentContent.contains(word)) return 'moyenne';
    }

    // Plusieurs messages rapprochés sans réponse = urgence moyenne
    final otherMessages = messages.where((m) => m.senderId != messages.first.senderId).length;
    if (messages.length > 3 && otherMessages == 0) return 'moyenne';

    return 'basse';
  }

  /// Extrait les questions en attente de reponse
  List<String> _extractPendingQuestions(
      List<Message> messages, String currentUserId) {
    if (messages.isEmpty) return [];

    final pendingQuestions = <String>[];
    final otherMessages =
        messages.where((m) => m.senderId != currentUserId).toList();

    // Chercher les questions dans les messages des autres
    for (int i = otherMessages.length - 1;
        i >= 0 && pendingQuestions.length < 3;
        i--) {
      final msg = otherMessages[i];
      if (msg.content.contains('?')) {
        // Verifier si cette question a ete repondue apres
        final msgIndex = messages.indexOf(msg);
        final hasAnswer = messages
            .skip(msgIndex + 1)
            .any((m) => m.senderId == currentUserId);

        if (!hasAnswer) {
          // Extraire la question (simplifiee)
          final question = msg.content.length > 80
              ? '${msg.content.substring(0, 80)}...'
              : msg.content;
          pendingQuestions.add(question);
        }
      }
    }

    return pendingQuestions;
  }

  /// Detecte le rythme de la conversation
  String _detectRhythm(List<Message> messages) {
    if (messages.length < 3) return 'debut';

    // Analyser la longueur moyenne des messages
    final avgLength = _calculateAverageMessageLength(messages);

    // Analyser le pattern d'echange
    int shortMessages = 0;
    int longMessages = 0;

    for (final msg in messages) {
      if (msg.content.length < 30) {
        shortMessages++;
      } else if (msg.content.length > 100) {
        longMessages++;
      }
    }

    if (shortMessages > messages.length * 0.7) return 'rapide';
    if (longMessages > messages.length * 0.5) return 'lent';
    return 'modere';
  }

  /// Calcule la longueur moyenne des messages
  double _calculateAverageMessageLength(List<Message> messages) {
    if (messages.isEmpty) return 0.0;
    final totalLength =
        messages.fold<int>(0, (sum, m) => sum + m.content.length);
    return totalLength / messages.length;
  }

  /// Detecte le moment de la journee
  String _detectTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'matin';
    if (hour >= 12 && hour < 18) return 'apres-midi';
    if (hour >= 18 && hour < 22) return 'soir';
    return 'nuit';
  }

  /// Detecte les intentions dans la conversation
  List<String> _detectIntentions(List<Message> messages) {
    if (messages.isEmpty) return [];

    final intentions = <String>[];
    final content = messages.map((m) => m.content.toLowerCase()).join(' ');

    // Patterns d'intention
    final intentionPatterns = {
      'planifier_rdv': [
        'on se voit',
        'rendez-vous',
        'rdv',
        'dispo',
        'libre',
        'quand',
        'rencontrer'
      ],
      'demander_aide': [
        'aide',
        'aider',
        'besoin',
        'probleme',
        'comment',
        'pourquoi',
        'stp',
        's\'il te plait'
      ],
      'partager_info': [
        'regarde',
        'voici',
        'j\'ai vu',
        'j\'ai trouve',
        'interessant',
        'info'
      ],
      'exprimer_emotion': [
        'content',
        'triste',
        'super',
        'genial',
        'decu',
        'fier',
        'heureux'
      ],
      'faire_proposition': [
        'on pourrait',
        'que dirais-tu',
        'et si',
        'je propose',
        'pourquoi pas'
      ],
      'confirmer': ['ok', 'd\'accord', 'parfait', 'entendu', 'ca marche', 'yes'],
      'decliner': ['non', 'pas possible', 'desole', 'je ne peux pas', 'annuler'],
    };

    intentionPatterns.forEach((intention, patterns) {
      if (patterns.any((p) => content.contains(p))) {
        intentions.add(intention);
      }
    });

    return intentions.take(3).toList();
  }

  /// Detecte le style de communication du contact
  String _detectContactStyle(List<Message> messages, String currentUserId) {
    final otherMessages =
        messages.where((m) => m.senderId != currentUserId).toList();
    if (otherMessages.isEmpty) return 'inconnu';

    int emojiCount = 0;
    int totalLength = 0;
    int exclamationCount = 0;

    for (final msg in otherMessages) {
      totalLength += msg.content.length;

      // Compter les emojis (simplifiee)
      final emojiPattern = RegExp(
          r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]',
          unicode: true);
      emojiCount += emojiPattern.allMatches(msg.content).length;

      // Compter les exclamations
      exclamationCount += '!'.allMatches(msg.content).length;
    }

    final avgLength = totalLength / otherMessages.length;
    final avgEmojis = emojiCount / otherMessages.length;

    if (avgEmojis > 1.5 || exclamationCount > otherMessages.length * 2) {
      return 'expressif';
    }
    if (avgLength < 25) return 'concis';
    if (avgLength > 100) return 'detaille';
    if (avgEmojis > 0.5) return 'emotionnel';

    return 'equilibre';
  }

  String _createConversationSummary(
    List<Message> messages,
    String currentUserId,
    List<String> topics, {
    bool isGroupChat = false,
    List<String>? participants,
  }) {
    if (messages.isEmpty) {
      return isGroupChat
          ? 'Nouvelle conversation de groupe'
          : 'Nouvelle conversation';
    }

    final otherMessages =
        messages.where((m) => m.senderId != currentUserId).toList();
    String summary = '';

    if (isGroupChat) {
      final participantCount = participants?.length ?? 0;
      if (messages.length <= 3) {
        summary =
            'Debut de discussion de groupe ($participantCount participants)';
      } else if (messages.length <= 10) {
        summary = 'Discussion de groupe en cours';
      } else {
        summary = 'Discussion de groupe active';
      }
    } else {
      if (messages.length <= 3) {
        summary = 'Debut de conversation';
      } else if (messages.length <= 10) {
        summary = 'Conversation en cours';
      } else {
        summary = 'Discussion active';
      }
    }

    if (topics.isNotEmpty && topics[0] != 'discussion generale') {
      summary += ' portant sur ${topics.take(2).join(", ")}';
    }

    if (otherMessages.isNotEmpty) {
      final lastOther = otherMessages.last.content;
      if (lastOther.contains('?')) {
        summary += '. Question en attente de reponse';
      }
    }

    return summary;
  }

  String _buildSystemPrompt(
    String mode,
    String userName,
    _ConversationAnalysis analysis, {
    bool isGroupChat = false,
    String? groupName,
  }) {
    final contextType = isGroupChat
        ? 'GROUPE${groupName != null ? " ($groupName)" : ""}'
        : 'CONVERSATION 1-1';

    final participantsInfo = isGroupChat && analysis.participants.isNotEmpty
        ? '\n- Participants: ${analysis.participants.join(", ")}'
        : '';

    // Contexte enrichi avec toutes les analyses
    final enrichedContext = analysis.toPromptContext();

    final base =
        '''Tu es un assistant IA conversationnel expert qui aide $userName a communiquer de maniere authentique et efficace.

TYPE DE CONVERSATION: $contextType
NOMBRE DE MESSAGES: ${analysis.messageCount}
RESUME: ${analysis.conversationSummary}

ANALYSE DETAILLEE:
$enrichedContext$participantsInfo''';

    if (mode == 'suggest') {
      final urgencyGuidance = analysis.urgency == 'haute'
          ? '\n- URGENT: Reponds de maniere claire et directe, propose une action concrete'
          : analysis.urgency == 'moyenne'
              ? '\n- Reponds dans un delai raisonnable, montre que tu as compris la demande'
              : '';

      final pendingQuestionsGuidance = analysis.pendingQuestions.isNotEmpty
          ? '\n- QUESTIONS EN ATTENTE A ADRESSER:\n  ${analysis.pendingQuestions.map((q) => '• $q').join('\n  ')}'
          : '';

      final styleGuidance = _getStyleGuidance(analysis.contactStyle);

      final groupSpecificRules = isGroupChat
          ? '''
- Dans un groupe, adresse-toi a tous ou mentionne des personnes specifiques si pertinent
- Evite les messages trop personnels dans un groupe
- Favorise l'engagement collectif et l'inclusion'''
          : '';

      return '''$base

MISSION - SUGGESTION DE REPONSE:
Tu dois proposer une reponse que $userName peut envoyer directement.

REGLES ABSOLUES:
- Reponds UNIQUEMENT avec le message suggere (aucune explication, aucun commentaire)
- Pas de guillemets, pas de preambule comme "Voici une suggestion:"
- 1-3 phrases maximum, naturelles et humaines
- Langue: francais courant (pas academique)
- Ne dis JAMAIS "En tant qu'assistant...", "Je suggere...", ou formules similaires
- Le message doit sembler ecrit par un humain, pas par une IA

ADAPTATION AU CONTEXTE:
- Ton: ${analysis.tone == 'informel' ? 'decontracte et direct' : analysis.tone == 'formel' ? 'poli et professionnel' : 'naturel et equilibre'}
- Rythme: ${analysis.rhythm == 'rapide' ? 'message court et percutant' : analysis.rhythm == 'lent' ? 'message plus developpe si necessaire' : 'longueur moderee'}$urgencyGuidance$pendingQuestionsGuidance$styleGuidance$groupSpecificRules''';
    }

    return '''$base

MISSION - AMELIORATION DE MESSAGE:
Tu dois ameliorer le brouillon de $userName tout en preservant son intention originale et sa personnalite.

REGLES ABSOLUES:
- Reponds UNIQUEMENT avec le message ameliore (aucune explication)
- Pas de guillemets, pas de commentaires, pas de "Version amelioree:"
- Garde la longueur et le ton similaires a l'original
- Corrige les fautes d'orthographe et de grammaire
- Ameliore la fluidite sans denaturer le message
- En francais

PRESERVATION DE L'AUTHENTICITE:
- Garde le style personnel de l'utilisateur
- Ne change pas les expressions familieres si elles sont appropriees au contexte
- Conserve les emojis si presents dans l'original''';
  }

  /// Retourne des conseils de style bases sur le style du contact
  String _getStyleGuidance(String contactStyle) {
    switch (contactStyle) {
      case 'expressif':
        return '\n- Le contact est expressif: tu peux utiliser des emojis et un ton enthousiaste';
      case 'concis':
        return '\n- Le contact est concis: privilegie les messages courts et directs';
      case 'detaille':
        return '\n- Le contact ecrit de longs messages: tu peux etre plus developpe';
      case 'emotionnel':
        return '\n- Le contact exprime ses emotions: montre de l\'empathie';
      default:
        return '';
    }
  }

  String _buildUserPrompt(
    String mode,
    String currentInput,
    List<Message> messages,
    String currentUserId,
    String currentUserName,
    _ConversationAnalysis analysis, {
    bool isGroupChat = false,
    String? groupName,
  }) {
    final contextMessages = _buildStructuredContext(
      messages,
      currentUserId,
      currentUserName,
      isGroupChat: isGroupChat,
    );

    if (mode == 'suggest') {
      final otherMessages =
          messages.where((m) => m.senderId != currentUserId).toList();

      if (otherMessages.isEmpty) {
        final startMessage = isGroupChat
            ? 'Propose un message pour que $currentUserName ${messages.isEmpty ? 'demarre' : 'relance'} la discussion dans ce groupe.'
            : 'Propose un message pour que $currentUserName ${messages.isEmpty ? 'demarre' : 'relance'} cette conversation.';

        return '''HISTORIQUE:
$contextMessages
 
MISSION:
$startMessage''';
      }

      final lastOther = otherMessages.last;
      final replyTo = isGroupChat
          ? 'Genere UNE reponse parfaite que $currentUserName peut envoyer au groupe (en repondant notamment a ${lastOther.senderName}).'
          : 'Genere UNE reponse parfaite que $currentUserName peut envoyer a ${lastOther.senderName}.';

      return '''HISTORIQUE:
$contextMessages
 
---
 
DERNIER MESSAGE:
${lastOther.senderName}: "${lastOther.content}"
 
MISSION:
$replyTo''';
    }

    return '''CONTEXTE:
$contextMessages
 
---
 
BROUILLON DE $currentUserName:
"$currentInput"
 
MISSION:
Ameliore ce brouillon en gardant le meme sens.''';
  }

  String _buildStructuredContext(
    List<Message> messages,
    String currentUserId,
    String currentUserName, {
    bool isGroupChat = false,
  }) {
    if (messages.isEmpty) {
      return isGroupChat
          ? '[Nouvelle conversation de groupe]'
          : '[Nouvelle conversation]';
    }

    final lines = <String>[];

    // Utiliser le nombre de messages de contexte configure
    if (messages.length > _contextMessageLimit) {
      final recentMessages =
          messages.sublist(messages.length - _contextMessageLimit);
      lines.add(
          '[${messages.length - _contextMessageLimit} messages precedents omis...]');
      lines.add('');

      for (var i = 0; i < recentMessages.length; i++) {
        final msg = recentMessages[i];
        final isMe = msg.senderId == currentUserId;
        final prefix = isMe ? '[MOI] $currentUserName' : msg.senderName;
        lines.add('${i + 1}. $prefix: "${msg.content}"');
      }
    } else {
      for (var i = 0; i < messages.length; i++) {
        final msg = messages[i];
        final isMe = msg.senderId == currentUserId;
        final prefix = isMe ? '[MOI] $currentUserName' : msg.senderName;
        lines.add('${i + 1}. $prefix: "${msg.content}"');
      }
    }

    return lines.join('\n');
  }
}

/// Classe pour stocker l'analyse de la conversation
class _ConversationAnalysis {
  final String tone;
  final String relationship;
  final List<String> topics;
  final String conversationSummary;
  final int messageCount;
  final String lastSpeaker;
  final String conversationFlow;
  final String emotionalTone;
  final List<String> participants;
  final bool isGroupChat;
  final String? groupName;

  // Nouveaux champs d'analyse enrichie
  final String urgency; // 'haute', 'moyenne', 'basse'
  final List<String> pendingQuestions; // Questions en attente de reponse
  final String rhythm; // 'rapide', 'modere', 'lent'
  final double averageMessageLength; // Longueur moyenne des messages
  final String timeOfDay; // 'matin', 'apres-midi', 'soir', 'nuit'
  final List<String> detectedIntentions; // Intentions detectees
  final String contactStyle; // 'expressif', 'concis', 'detaille', 'emotionnel'

  _ConversationAnalysis({
    required this.tone,
    required this.relationship,
    required this.topics,
    required this.conversationSummary,
    required this.messageCount,
    required this.lastSpeaker,
    required this.conversationFlow,
    required this.emotionalTone,
    required this.participants,
    required this.isGroupChat,
    this.groupName,
    this.urgency = 'basse',
    this.pendingQuestions = const [],
    this.rhythm = 'modere',
    this.averageMessageLength = 0.0,
    this.timeOfDay = 'journee',
    this.detectedIntentions = const [],
    this.contactStyle = 'neutre',
  });

  /// Retourne un resume complet de l'analyse pour le prompt
  String toPromptContext() {
    final buffer = StringBuffer();
    buffer.writeln('- Ton: $tone');
    buffer.writeln('- Relation: $relationship');
    buffer.writeln('- Sujets: ${topics.join(", ")}');
    buffer.writeln('- Emotion: $emotionalTone');
    buffer.writeln('- Flux: $conversationFlow');
    buffer.writeln('- Urgence: $urgency');
    buffer.writeln('- Rythme: $rhythm');
    buffer.writeln('- Style de contact: $contactStyle');
    if (pendingQuestions.isNotEmpty) {
      buffer.writeln('- Questions en attente: ${pendingQuestions.join("; ")}');
    }
    if (detectedIntentions.isNotEmpty) {
      buffer.writeln('- Intentions detectees: ${detectedIntentions.join(", ")}');
    }
    buffer.writeln('- Moment: $timeOfDay');
    buffer.writeln('- Longueur moyenne: ${averageMessageLength.toStringAsFixed(0)} caracteres');
    return buffer.toString();
  }
}

/// Classe pour le cache d'analyse
class _CachedAnalysis {
  final _ConversationAnalysis analysis;
  final DateTime timestamp;

  _CachedAnalysis(this.analysis, this.timestamp);
}
