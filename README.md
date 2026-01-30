# AI Chat - Application de Messagerie Intelligente

Application de messagerie en temps réel avec suggestions IA, développée avec Flutter (Web) et un backend Node.js.

## Fonctionnalités

### Messagerie
- Chat 1-à-1 en temps réel
- Groupes de discussion
- Listes de diffusion (broadcast)
- Statuts de messages (envoyé ✓, délivré ✓✓, lu ✓✓)
- Indicateur "en train d'écrire"
- Réactions aux messages (emojis)
- Édition et suppression de messages
- Réponse à un message
- Compteur de messages non lus

### Intelligence Artificielle
- Suggestions de réponses contextuelles
- Analyse de conversation (ton, urgence, intentions)
- Mode **Suggestion** : génère une réponse (champ vide)
- Mode **Amélioration** : reformule votre texte (champ rempli)
- Modèle principal : `llama-3.1-70b-versatile`
- Modèle de secours : `llama-3.1-8b-instant`

### Interface
- Design responsive (mobile, tablette, desktop)
- Navigation à onglets (Discussions, Contacts, Paramètres)
- Badges de notifications non lues
- Recherche dans les conversations

---

## Architecture

```
Recrutement_AI_TEST/
├── lib/                          # Code Flutter (Frontend)
│   ├── config/                   # Configuration
│   │   ├── api_config.dart       # URLs backend
│   │   └── api_keys.dart         # Clés API (gitignore)
│   ├── models/                   # Modèles de données
│   │   ├── app_user.dart
│   │   ├── message.dart
│   │   ├── conversation.dart
│   │   ├── group.dart
│   │   └── broadcast_list.dart
│   ├── providers/                # State management
│   │   └── chat_provider.dart
│   ├── screens/                  # Écrans UI
│   │   ├── home_screen.dart
│   │   ├── login_screen.dart
│   │   ├── chat_screen.dart
│   │   ├── chat_tab.dart
│   │   ├── contact_tab.dart
│   │   └── group_chat_screen.dart
│   ├── services/                 # Services
│   │   ├── ai_service.dart
│   │   ├── firestore_service.dart
│   │   ├── user_service.dart
│   │   └── notification_service.dart
│   └── widgets/                  # Composants réutilisables
│       ├── chat_input.dart
│       └── message_bubble.dart
├── web/                          # Assets Web
│   ├── index.html                # Config Firebase + VAPID
│   └── firebase-messaging-sw.js  # Service Worker
├── backend/                      # Backend Node.js
│   └── src/
│       ├── ai/                   # Service IA (Groq)
│       │   ├── ai-service.js
│       │   ├── conversation-analyzer.js
│       │   └── prompt-builder.js
│       ├── config/               # Configuration
│       ├── routes/               # Routes API
│       └── services/             # Services
├── firestore.rules               # Règles de sécurité Firestore
└── firebase.json                 # Configuration Firebase
```

---

## Configuration Render.com (Backend)

### Variables d'environnement OBLIGATOIRES

| Variable | Valeur | Description |
|----------|--------|-------------|
| `GROQ_API_KEY` | `gsk_votre_cle_groq_ici` | Clé API Groq (obtenir sur console.groq.com) |

### Variables OPTIONNELLES (valeurs par défaut)

| Variable | Défaut | Description |
|----------|--------|-------------|
| `NODE_ENV` | `production` | Environnement |
| `AI_MODEL` | `llama-3.1-70b-versatile` | Modèle IA principal |
| `AI_FALLBACK_MODEL` | `llama-3.1-8b-instant` | Modèle de secours |
| `AI_MAX_TOKENS` | `250` | Tokens max par réponse |
| `AI_TEMPERATURE` | `0.7` | Créativité (0-1) |
| `AI_TOP_P` | `0.9` | Nucleus sampling |
| `AI_PRESENCE_PENALTY` | `0.1` | Pénalité de répétition |
| `FIREBASE_PROJECT_ID` | `ai-chat-23aa5` | ID du projet Firebase |

### Configuration Render

1. **Build Command** : `cd backend && npm install`
2. **Start Command** : `cd backend && npm start`

---

## Configuration Frontend

### Firebase (web/index.html)

```javascript
window.firebaseConfig = {
  apiKey: "AIzaSyA4gFkg8wz1zB7cBaQfLHf3Lx2fXoBY9Zc",
  authDomain: "ai-chat-23aa5.firebaseapp.com",
  projectId: "ai-chat-23aa5",
  storageBucket: "ai-chat-23aa5.firebasestorage.app",
  messagingSenderId: "364659039092",
  appId: "1:364659039092:web:d06724261cff094a0aaa21",
  vapidKey: "BKYvvM8UNIJR0Oes2Z_CNtOlndKmeG17Ek17Rs92hIQQHvy802OxqGAkb1bY0fGJaKCFsu1iX8SArRYSWZUFD_M"
};
```

### Clé Groq (lib/config/api_keys.dart)

Créer ce fichier (ne pas commiter) :

```dart
class ApiKeys {
  static const String groqApiKey = 'gsk_votre_cle_groq_ici';

  static bool get isGroqConfigured =>
      groqApiKey.isNotEmpty && !groqApiKey.contains('YOUR_');
}
```

---

## Installation

### Frontend (Flutter Web)

```bash
# Installer les dépendances
flutter pub get

# Créer api_keys.dart
cp lib/config/api_keys.example.dart lib/config/api_keys.dart
# Éditer avec votre clé Groq

# Lancer en développement
flutter run -d chrome

# Build pour production
flutter build web
```

### Backend (Node.js)

```bash
cd backend

# Installer les dépendances
npm install

# Créer .env
echo "GROQ_API_KEY=votre_cle_ici" > .env

# Lancer en développement
npm run dev

# Lancer en production
npm start
```

---

## Déploiement

### Frontend → Firebase Hosting

```bash
flutter build web
firebase deploy --only hosting
```

### Backend → Render.com

1. Connecter le repo GitHub
2. Créer un **Web Service**
3. Configurer les variables d'environnement (voir ci-dessus)

---

## API Backend

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `GET` | `/health` | Vérification santé |
| `POST` | `/api/ai/suggest` | Génère une suggestion |
| `POST` | `/api/ai/analyze` | Analyse une conversation |
| `GET` | `/api/ai/status` | Statut du service IA |

### Exemple

```bash
curl -X POST https://votre-backend.onrender.com/api/ai/suggest \
  -H "Content-Type: application/json" \
  -d '{
    "currentInput": "",
    "messages": [{"content": "Salut!", "senderId": "u2", "senderName": "Alice"}],
    "currentUserId": "u1",
    "currentUserName": "Bob"
  }'
```

---

## Structure Firestore

```
users/{userId}
  ├── displayName, email, isOnline, lastSeen
  ├── typingIn: {conversationId: timestamp}
  └── fcmToken

conversations/{conversationId}
  ├── participants, lastMessage, lastMessageTime
  ├── unreadCounts: {userId: count}
  └── messages/{messageId}
        ├── content, senderId, senderName, timestamp
        ├── status: 'sent' | 'delivered' | 'read'
        └── reactions: {userId: emoji}

groups/{groupId}
  ├── name, members, admins, createdBy
  └── messages/{messageId}

broadcastLists/{listId}
  ├── name, ownerId, recipients
```

---

## Dépannage

### L'app ne fonctionne pas sur mobile (hors navigation privée)

1. Vider le cache du navigateur
2. Désinstaller le Service Worker :
   - Chrome mobile : Paramètres > Confidentialité > Effacer données de navigation
3. Recharger la page

### Erreur "permission-denied" Firestore

1. Déployer les règles Firestore :
   ```bash
   firebase deploy --only firestore:rules
   ```

### Erreur d'index Firestore

Cliquer sur le lien dans l'erreur console pour créer l'index automatiquement.

---

## Technologies

| Composant | Technologies |
|-----------|-------------|
| **Frontend** | Flutter 3.x, Provider, Firebase |
| **Backend** | Node.js 18+, Express, Groq SDK |
| **Database** | Cloud Firestore |
| **Auth** | Firebase Authentication |
| **Hosting** | Firebase Hosting, Render.com |
| **IA** | LLaMA 3.1 70B/8B via Groq API |

---

## Licence

Projet privé - Tous droits réservés.
