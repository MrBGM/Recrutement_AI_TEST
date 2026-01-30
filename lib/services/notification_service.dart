import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Récupère la clé VAPID depuis window.firebaseConfig (index.html)
  static String? _getVapidKeyFromConfig() {
    if (!kIsWeb) return null;

    try {
      final firebaseConfig = globalContext['firebaseConfig'];
      if (firebaseConfig != null && firebaseConfig.isA<JSObject>()) {
        final vapidKey = (firebaseConfig as JSObject)['vapidKey'];
        if (vapidKey != null && vapidKey.isA<JSString>()) {
          return (vapidKey as JSString).toDart;
        }
      }
    } catch (e) {
      print('⚠️ Impossible de lire window.firebaseConfig: $e');
    }
    return null;
  }

  /// Initialise le service de notifications (version WEB)
  Future<void> initialize(String userId) async {
    if (!kIsWeb) {
      print('⚠️ Cette version est optimisée pour le Web');
      return;
    }

    // Demander la permission
    await _requestPermission();

    // Récupérer la clé VAPID depuis window.firebaseConfig (centralisé dans index.html)
    final vapidKey = _getVapidKeyFromConfig();

    if (vapidKey == null || vapidKey.isEmpty) {
      print('⚠️ Clé VAPID non trouvée dans window.firebaseConfig');
      print('   Vérifiez que vapidKey est défini dans web/index.html');
      return;
    }

    try {
      // Obtenir le token FCM
      _fcmToken = await _messaging.getToken(vapidKey: vapidKey);

      if (_fcmToken != null) {
        print('✅ Token FCM Web obtenu: ${_fcmToken!.substring(0, 20)}...');
        await _saveTokenToFirestore(userId, _fcmToken!);
      }

      // Écouter les changements de token
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _saveTokenToFirestore(userId, newToken);
      });

      // Gérer les messages au premier plan
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📬 Message reçu: ${message.notification?.title}');

        // Sur Web, afficher une notification navigateur
        if (message.notification != null) {
          _showBrowserNotification(
            title: message.notification!.title ?? 'Nouveau message',
            body: message.notification!.body ?? '',
          );
        }
      });
    } catch (e) {
      print('❌ Erreur initialisation notifications: $e');
    }
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Notifications autorisées (Web)');
    } else {
      print('❌ Notifications refusées');
    }
  }

  Future<void> _saveTokenToFirestore(String userId, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'fcmToken': token});
      print('✅ Token FCM sauvegardé');
    } catch (e) {
      print('❌ Erreur sauvegarde token: $e');
    }
  }

  void _showBrowserNotification({
    required String title,
    required String body,
  }) {
    // Sur Web, on utilise l'API Notification du navigateur
    print('🔔 Notification: $title - $body');
    // Note: Les vraies notifications navigateur nécessitent le Service Worker
  }

  Future<void> dispose() async {
    // Cleanup
  }
}
