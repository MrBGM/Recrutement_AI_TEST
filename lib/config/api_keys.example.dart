/// Configuration des clés API
///
/// INSTRUCTIONS :
/// 1. Copiez ce fichier et renommez-le en 'api_keys.dart'
/// 2. Remplacez les valeurs par vos vraies clés
/// 3. Ne commitez JAMAIS le fichier api_keys.dart (il est dans .gitignore)
///
/// Pour obtenir une clé API Groq :
/// - Allez sur https://console.groq.com/
/// - Créez un compte ou connectez-vous
/// - Générez une nouvelle clé API
///
/// Pour obtenir la clé VAPID (Firebase Cloud Messaging Web) :
/// - Allez dans Firebase Console > Project Settings > Cloud Messaging
/// - Générez ou copiez la "Web Push certificate" (clé publique VAPID)

class ApiKeys {
  // Clé API Groq pour les suggestions IA
  static const String groqApiKey = 'YOUR_GROQ_API_KEY_HERE';

  // Clé VAPID pour les notifications push Web (clé publique)
  static const String vapidKey = 'YOUR_VAPID_KEY_HERE';

  /// Vérifie si la clé Groq est configurée
  static bool get isGroqConfigured =>
      groqApiKey.isNotEmpty && !groqApiKey.contains('YOUR_');

  /// Vérifie si la clé VAPID est configurée
  static bool get isVapidConfigured =>
      vapidKey.isNotEmpty && !vapidKey.contains('YOUR_');
}
