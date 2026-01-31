# AI Chat - Application de Messagerie Intelligente

> Application de messagerie en temps réel avec assistance IA, développée en Flutter pour le web avec backend Node.js.

## Table des Matières

1. [Vue d'ensemble](#vue-densemble)
2. [Architecture](#architecture)
3. [Fonctionnalités Détaillées](#fonctionnalités-détaillées)
4. [Logique Métier](#logique-métier)
5. [Justification des Choix Techniques](#justification-des-choix-techniques)
6. [Scénarios d'Utilisation](#scénarios-dutilisation)
7. [Structure des Données](#structure-des-données)
8. [Configuration et Déploiement](#configuration-et-déploiement)
9. [API Reference](#api-reference)

---

## Vue d'ensemble

### Qu'est-ce que AI Chat ?

AI Chat est une application de messagerie instantanée qui combine :
- **Messagerie temps réel** : Conversations individuelles et groupes
- **Intelligence Artificielle** : Suggestions de réponses contextuelles via Groq (LLaMA)
- **Expérience WhatsApp-like** : Indicateurs de frappe, statuts de lecture, réactions

### Technologies Utilisées

| Composant | Technologie | Justification |
|-----------|-------------|---------------|
| Frontend | Flutter Web | Cross-platform, UI riche, hot reload |
| Backend | Node.js + Express | Léger, async natif, écosystème npm |
| Base de données | Firebase Firestore | Temps réel, offline-first, scaling auto |
| Authentification | Firebase Auth | Sécurisé, intégré, OAuth ready |
| IA | Groq API (LLaMA 3.1) | Rapide, économique, qualité comparable à GPT |
| Notifications | Firebase Cloud Messaging | Push natif, fiable |

---

## Architecture

### Vue Globale

```
┌─────────────────────────────────────────────────────────────────┐
│                        UTILISATEUR                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      FLUTTER WEB APP                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │   Screens   │  │  Providers  │  │       Services          │  │
│  │  - Login    │  │  - Chat     │  │  - AuthService          │  │
│  │  - Home     │  │    Provider │  │  - UserService          │  │
│  │  - Chat     │  │             │  │  - FirestoreService     │  │
│  │  - Group    │  │             │  │  - AIService            │  │
│  │  - Settings │  │             │  │  - NotificationService  │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
           │                                      │
           ▼                                      ▼
┌─────────────────────┐              ┌─────────────────────────────┐
│   FIREBASE SUITE    │              │      BACKEND NODE.JS        │
│  ┌───────────────┐  │              │  ┌───────────────────────┐  │
│  │   Firestore   │  │              │  │   Express Server      │  │
│  │   (Database)  │  │              │  │   - /api/ai/suggest   │  │
│  ├───────────────┤  │              │  │   - /api/ai/analyze   │  │
│  │     Auth      │  │              │  │   - /health           │  │
│  ├───────────────┤  │              │  └───────────────────────┘  │
│  │      FCM      │  │              │             │               │
│  │  (Push Notif) │  │              │             ▼               │
│  └───────────────┘  │              │  ┌───────────────────────┐  │
└─────────────────────┘              │  │      GROQ API         │  │
                                     │  │   (LLaMA 3.1 70B)     │  │
                                     │  └───────────────────────┘  │
                                     └─────────────────────────────┘
```

### Structure des Fichiers

```
lib/
├── main.dart                 # Point d'entrée, AuthWrapper
├── config/
│   └── api_config.dart       # URLs backend, clés API
├── models/
│   ├── app_user.dart         # Modèle utilisateur
│   ├── message.dart          # Modèle message
│   ├── conversation.dart     # Modèle conversation
│   ├── group.dart            # Modèle groupe
│   └── broadcast_list.dart   # Modèle liste de diffusion
├── providers/
│   └── chat_provider.dart    # État de la conversation
├── screens/
│   ├── login_screen.dart     # Authentification
│   ├── home_screen.dart      # Navigation principale
│   ├── chat_screen.dart      # Conversation 1-1
│   ├── chat_tab.dart         # Liste des conversations
│   ├── contact_tab.dart      # Contacts et groupes
│   ├── settings_tab.dart     # Paramètres
│   └── group_chat_screen.dart# Conversation de groupe
├── services/
│   ├── auth_service.dart     # Authentification Firebase
│   ├── user_service.dart     # Gestion utilisateurs
│   ├── firestore_service.dart# Opérations Firestore
│   ├── ai_service.dart       # Intégration Groq
│   └── notification_service.dart # Push notifications
└── widgets/
    ├── message_bubble.dart   # Bulle de message
    └── chat_input.dart       # Zone de saisie

backend/
├── src/
│   ├── index.js              # Serveur Express
│   ├── config/
│   │   └── index.js          # Configuration
│   ├── routes/
│   │   └── ai.routes.js      # Routes IA
│   ├── ai/
│   │   └── ai-service.js     # Service Groq
│   └── middleware/
│       ├── error-handler.js  # Gestion erreurs
│       └── validate-request.js # Validation
└── package.json
```

---

## Fonctionnalités Détaillées

### 1. Authentification

#### Inscription
```dart
// lib/services/auth_service.dart
Future<UserCredential?> signUp({
  required String email,
  required String password,
  required String displayName,
}) async {
  // 1. Créer le compte Firebase Auth
  final credential = await _auth.createUserWithEmailAndPassword(...);

  // 2. Créer le profil Firestore
  await _userService.createUserProfile(
    userId: credential.user!.uid,
    email: email,
    displayName: displayName,
  );

  // 3. Mettre à jour le displayName dans Auth
  await credential.user!.updateDisplayName(displayName);
}
```

**Pourquoi cette approche ?**
- Séparation des données Auth (credentials) et Firestore (profil enrichi)
- Permet d'ajouter des champs personnalisés (status, photoUrl, etc.)
- Le profil Firestore est synchronisé en temps réel avec tous les clients

---

### 2. Messagerie Temps Réel

#### Envoi de Message

```dart
// lib/services/firestore_service.dart
Future<String> sendMessage({
  required String conversationId,
  required String content,
  required String senderId,
  required String senderName,
}) async {
  // 1. S'assurer que la conversation existe
  final participantIds = conversationId.split('_');
  await _ensureConversationExists(conversationId, participantIds);

  // 2. Créer le document message
  final messageRef = _firestore
      .collection('conversations')
      .doc(conversationId)
      .collection('messages')
      .doc(); // ID auto-généré

  final messageData = {
    'id': messageRef.id,
    'content': content,
    'senderId': senderId,
    'timestamp': Timestamp.fromDate(DateTime.now()),
    'status': 'sent',
    'reactions': {},
  };

  await messageRef.set(messageData);

  // 3. Mettre à jour les métadonnées
  final otherUserId = _getOtherUserId(conversationId, senderId);
  await _updateConversationMetadata(
    conversationId,
    content: content,
    incrementUnreadFor: otherUserId,
  );
}
```

**Logique métier expliquée :**

1. **ID de conversation** : `userId1_userId2` (triés alphabétiquement)
   ```dart
   String getConversationId(String userId1, String userId2) {
     final sortedIds = [userId1, userId2]..sort();
     return '${sortedIds[0]}_${sortedIds[1]}';
   }
   ```
   - Garantit un ID unique et cohérent entre deux utilisateurs
   - Peu importe qui initie la conversation

2. **Compteur non lus** : Incrémenté pour l'autre utilisateur
   ```dart
   data['unreadCounts.$incrementUnreadFor'] = FieldValue.increment(1);
   ```

---

### 3. Indicateur de Frappe (Typing)

#### Comment ça fonctionne

```
Utilisateur A tape → Firestore users/{A}/typingIn.{convId} = timestamp
                                    ↓
                     (Firestore sync ~1-3 secondes)
                                    ↓
Utilisateur B écoute → Voit "A est en train d'écrire..." avec 3 points animés
```

#### Implémentation

```dart
Future<void> setTypingStatus({
  required String conversationId,
  required String userId,
  required bool isTyping,
}) async {
  if (isTyping) {
    await _firestore.collection('users').doc(userId).update({
      'typingIn.$conversationId': FieldValue.serverTimestamp(),
    });

    // Auto-arrêt après 10 secondes
    _typingTimers[conversationId] = Timer(Duration(seconds: 10), () {
      setTypingStatus(conversationId: conversationId, userId: userId, isTyping: false);
    });
  } else {
    await _firestore.collection('users').doc(userId).update({
      'typingIn.$conversationId': FieldValue.delete(),
    });
  }
}
```

**Pourquoi un Timer d'auto-arrêt ?**
- L'utilisateur peut fermer l'app sans "arrêter de taper"
- Évite les indicateurs "fantômes" bloqués

#### Vérification (30 secondes de tolérance)

```dart
bool isTypingIn(String conversationId) {
  final typingValue = typingIn[conversationId];
  if (typingValue == null) return false;

  final typingTime = typingValue is Timestamp
      ? typingValue.toDate()
      : typingValue as DateTime;

  // Tolérance de 30 secondes pour la latence Firestore
  return DateTime.now().difference(typingTime).inSeconds < 30;
}
```

#### Animation des 3 points (Style WhatsApp)

```dart
class _ThreeDotsAnimation extends StatefulWidget {
  // 3 contrôleurs pour 3 points avec animation séquentielle
  // Chaque point rebondit avec un délai de 150ms
}
```

---

### 4. Intelligence Artificielle

#### Flux de Génération de Suggestion

```
┌──────────────────┐
│ Utilisateur      │
│ clique ✨ AI     │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────────────────────────┐
│ AIService.generateSuggestion()                   │
│                                                  │
│ 1. Récupérer les 15 derniers messages            │
│ 2. Analyser la conversation (cache 5 min)        │
│    - Ton (formel/informel)                       │
│    - Relation (collègue/ami/famille/couple)      │
│    - Questions en attente                        │
│    - Urgence                                     │
│ 3. Construire le prompt contextuel               │
│ 4. Appeler le backend → Groq API                 │
└────────┬─────────────────────────────────────────┘
         │
         ▼
┌──────────────────┐
│ Suggestion:      │
│ "Cool ! Tu fais  │
│ quoi ce weekend?"│
└──────────────────┘
```

#### Deux Modes de Fonctionnement

| Mode | Déclencheur | Comportement |
|------|-------------|--------------|
| **Suggérer** | Champ vide + clic ✨ | Génère une nouvelle réponse contextuelle |
| **Améliorer** | Texte présent + clic ✨ | Améliore le brouillon en gardant l'intention |

#### Analyse de Conversation

```dart
Map<String, dynamic> _analyzeConversation(List<Message> messages) {
  return {
    'tone': _detectTone(messages),           // 'formal' | 'informal'
    'relationship': _detectRelationship(messages), // 'friend' | 'professional'
    'pendingQuestions': _extractPendingQuestions(messages),
    'urgency': _detectUrgency(messages),
    'topics': _extractTopics(messages),
  };
}
```

---

### 5. Groupes

#### Création de Groupe

```dart
Future<String> createGroup({
  required String name,
  required List<String> memberIds,
  required String createdBy,
}) async {
  final groupData = {
    'name': name,
    'memberIds': memberIds,
    'adminIds': [createdBy], // Le créateur est admin
    'createdBy': createdBy,
    'unreadCounts': {for (var id in memberIds) id: 0},
  };

  await groupRef.set(groupData);
}
```

**Règles de gestion :**
- Le créateur devient automatiquement admin
- Seuls les admins peuvent modifier/supprimer le groupe
- Tout membre peut quitter le groupe

---

### 6. Listes de Diffusion (Broadcast)

#### Concept

Envoyer un message à plusieurs personnes **individuellement** (pas un groupe).

```
┌─────────────────┐
│ Broadcast       │
│ "Famille"       │
│ - Papa, Maman   │
└────────┬────────┘
         │ "Bonne année !"
         ▼
┌───────────┐  ┌───────────┐
│Conv: Papa │  │Conv: Maman│
│"Bonne     │  │"Bonne     │
│ année !"  │  │ année !"  │
└───────────┘  └───────────┘
```

**Avantage vs Groupe :** Les destinataires ne voient pas les autres.

---

### 7. Statuts de Message

```
SENDING → SENT → DELIVERED → READ
   │        │         │         │
   │        │         │         └─ Double coche bleue ✓✓
   │        │         └─ Double coche grise ✓✓
   │        └─ Simple coche ✓
   └─ Spinner
```

---

### 8. Réactions aux Messages

```dart
Future<void> addReaction({
  required String messageId,
  required String userId,
  required String emoji,
}) async {
  await messageDoc.update({
    'reactions.$userId': emoji, // Map userId → emoji
  });
}
```

**Structure :** `{ "user123": "❤️", "user456": "😂" }`

---

## Scénarios d'Utilisation

### Scénario 1 : Première Conversation

**Contexte :** Alice veut envoyer un message à Bob.

```
1. Alice clique sur Bob dans les contacts
2. conversationId = "alice123_bob456" (généré automatiquement, trié)
3. _ensureConversationExists() crée le document
4. Alice envoie "Salut !"
5. Bob reçoit via Stream en temps réel
6. Badge "1" s'affiche pour Bob
```

**Résultat :** Alice voit ✓ (sent), Bob voit le badge

---

### Scénario 2 : Utilisation de l'IA

**Conversation :**
```
Paul: "Tu fais quoi ce weekend ?"
Marie: [clique ✨ AI avec champ vide]
```

**Analyse :**
- Ton: informal
- Question en attente: "Tu fais quoi ce weekend ?"

**Suggestion générée :** "Pas grand-chose, je pensais me reposer. Et toi ?"

---

### Scénario 3 : Amélioration de Message

**Conversation professionnelle :**
```
Manager: "Pouvez-vous confirmer votre présence ?"
Tom tape: "ok pour la réunion"
Tom clique ✨ AI
```

**Suggestion :** "Bonjour, je vous confirme ma présence. Cordialement."

---

### Scénario 4 : Indicateur de Frappe

```
T+0s   : Alice tape
T+0s   : Firestore mis à jour
T+3s   : Bob voit "Alice ● ● ●" (3 points animés)
T+10s  : Auto-arrêt si Alice ne tape plus
```

---

## Justification des Choix Techniques

### Pourquoi Flutter Web ?

| Alternative | Inconvénient | Flutter |
|-------------|--------------|---------|
| React | Pas de partage code mobile | Code unique iOS/Android/Web |
| Angular | Courbe apprentissage | Hot reload, productivité |

### Pourquoi Firestore ?

```dart
// Temps réel SANS polling
Stream<List<Message>> getMessages() {
  return firestore.collection('messages').snapshots();
}
```

### Pourquoi Groq (LLaMA) vs GPT ?

| Critère | GPT-4 | LLaMA 3.1 (Groq) |
|---------|-------|------------------|
| Latence | ~2-5s | ~0.5-1s |
| Coût | $30/1M tokens | $0.59/1M tokens |

### Pourquoi Singleton pour les Services ?

```dart
class FirestoreService {
  static final _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;

  final Map<String, Timer> _typingTimers = {}; // Partagé
}
```

Évite les fuites mémoire et garantit un état cohérent.

---

## Structure des Données

### Collection `users`

```javascript
{
  id: "abc123",
  displayName: "Marie",
  email: "marie@example.com",
  isOnline: true,
  lastSeen: Timestamp,
  typingIn: { "abc123_def456": Timestamp },
  fcmToken: "dK8x...",
  photoUrl: "https://...",
  status: "Disponible"
}
```

### Collection `conversations`

```javascript
{
  id: "abc123_def456",
  participantIds: ["abc123", "def456"],
  lastMessage: "À demain !",
  lastMessageTime: Timestamp,
  unreadCounts: { "abc123": 0, "def456": 2 }
}
```

### Sous-collection `messages`

```javascript
{
  id: "msg123",
  content: "Salut !",
  senderId: "abc123",
  senderName: "Marie",
  timestamp: Timestamp,
  status: "read",
  reactions: { "def456": "❤️" },
  isEdited: false,
  isDeletedForEveryone: false
}
```

---

## Configuration et Déploiement

### Variables d'Environnement Backend (Render.com)

| Variable | Description | Obligatoire |
|----------|-------------|-------------|
| `GROQ_API_KEY` | Clé API Groq | ✅ Oui |
| `NODE_ENV` | `production` | ✅ Oui |
| `PORT` | Port (défaut: 3000) | Non |
| `CORS_ORIGINS` | URLs autorisées | Non |

### Firebase Configuration (`web/index.html`)

```html
<script>
  const firebaseConfig = {
    apiKey: "AIza...",
    projectId: "ai-chat-23aa5",
    vapidKey: "BKYvvM8..."
  };
</script>
```

### Commandes de Déploiement

```bash
# Frontend
flutter build web --release
firebase deploy --only hosting

# Firestore Rules
firebase deploy --only firestore:rules
```

---

## API Reference

### `POST /api/ai/suggest`

**Request :**
```json
{
  "currentInput": "",
  "messages": [{"content": "Salut", "senderId": "user1"}],
  "currentUserId": "user2",
  "currentUserName": "Bob"
}
```

**Response :**
```json
{
  "success": true,
  "data": {
    "suggestion": "Hey ! Ça va ?",
    "mode": "suggest"
  }
}
```

### `GET /health`

**Response :** `{ "status": "ok" }`

---

## Licence

MIT License
