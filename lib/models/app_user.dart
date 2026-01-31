import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle représentant un utilisateur de l'application (amélioré)
class AppUser {
  final String id;
  final String displayName;
  final String email;
  final bool isOnline;
  final DateTime? lastSeen;

  // Notifications
  final String? fcmToken; // Pour notifications push
  final bool notificationsEnabled;

  // Statut d'écriture - CORRIGÉ : Map<String, dynamic> au lieu de Map<String, DateTime>
  final Map<String, dynamic> typingIn; // conversationId -> timestamp

  // Préférences
  final String? photoUrl;
  final String? status; // Bio/statut
  final DateTime? createdAt;

  // Compteurs
  final int unreadCount; // Total messages non lus

  AppUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.isOnline,
    this.lastSeen,
    this.fcmToken,
    this.notificationsEnabled = true,
    this.typingIn = const {}, // ← INITIALISATION PAR DÉFAUT
    this.photoUrl,
    this.status,
    this.createdAt,
    this.unreadCount = 0,
  });

  /// Crée un AppUser depuis un document Firestore
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Convertir typingIn map - GESTION DES TYPES CORRECTE
    final typingInRaw = data['typingIn'] as Map<String, dynamic>? ?? {};
    final typingInMap = <String, dynamic>{};

    typingInRaw.forEach((key, value) {
      if (value is Timestamp) {
        typingInMap[key] = value.toDate(); // Convertir Timestamp en DateTime
      } else if (value is DateTime) {
        typingInMap[key] = value;
      }
    });

    return AppUser(
      id: doc.id,
      displayName: data['displayName'] ?? 'Utilisateur',
      email: data['email'] ?? '',
      isOnline: data['isOnline'] ?? false,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
      fcmToken: data['fcmToken'],
      notificationsEnabled: data['notificationsEnabled'] ?? true,
      typingIn: typingInMap, // ← Map<String, dynamic>
      photoUrl: data['photoUrl'],
      status: data['status'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      unreadCount: data['unreadCount'] ?? 0,
    );
  }

  /// Convertit en Map pour Firestore
  Map<String, dynamic> toMap() {
    // Convertir typingIn map pour Firestore
    final typingInFirestore = <String, Timestamp>{};

    typingIn.forEach((key, value) {
      if (value is DateTime) {
        typingInFirestore[key] = Timestamp.fromDate(value);
      }
    });

    return {
      'displayName': displayName,
      'email': email,
      'isOnline': isOnline,
      if (lastSeen != null) 'lastSeen': Timestamp.fromDate(lastSeen!),
      if (fcmToken != null) 'fcmToken': fcmToken,
      'notificationsEnabled': notificationsEnabled,
      'typingIn': typingInFirestore,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (status != null) 'status': status,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      'unreadCount': unreadCount,
    };
  }

  /// Vérifie si l'utilisateur est en train d'écrire dans une conversation - CORRIGÉ
  bool isTypingIn(String conversationId) {
    final typingValue = typingIn[conversationId];

    // Si la valeur existe (même récente), l'utilisateur tape
    // La suppression est gérée par le timer automatique
    if (typingValue == null) {
      print('⏱️ isTypingIn: typingValue is null for $conversationId');
      return false;
    }

    DateTime typingTime;

    // Gérer les différents types possibles
    if (typingValue is Timestamp) {
      typingTime = typingValue.toDate();
      print('⏱️ isTypingIn: Timestamp converted to $typingTime');
    } else if (typingValue is DateTime) {
      typingTime = typingValue;
      print('⏱️ isTypingIn: Already DateTime: $typingTime');
    } else {
      // Type inconnu mais présent - considérer comme en train d'écrire
      print('⏱️ isTypingIn: Unknown type ${typingValue.runtimeType}, returning true');
      return true;
    }

    final now = DateTime.now();
    final diffSeconds = now.difference(typingTime).inSeconds;
    // Tolérance de 30 secondes pour gérer la latence Firestore
    final result = diffSeconds < 30;

    print('⏱️ isTypingIn: now=$now, typingTime=$typingTime, diff=${diffSeconds}s, result=$result');

    return result;
  }

  /// Copie avec typingIn mis à jour - CORRIGÉ
  AppUser copyWithTyping(String conversationId, bool isTyping) {
    final newTypingIn = Map<String, dynamic>.from(typingIn);

    if (isTyping) {
      newTypingIn[conversationId] = DateTime.now();
    } else {
      newTypingIn.remove(conversationId);
    }

    return copyWith(typingIn: newTypingIn);
  }

  /// Copie avec modifications - CORRIGÉ
  AppUser copyWith({
    String? id,
    String? displayName,
    String? email,
    bool? isOnline,
    DateTime? lastSeen,
    String? fcmToken,
    bool? notificationsEnabled,
    Map<String, dynamic>? typingIn,
    String? photoUrl,
    String? status,
    DateTime? createdAt,
    int? unreadCount,
  }) {
    return AppUser(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      fcmToken: fcmToken ?? this.fcmToken,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      typingIn: typingIn ?? this.typingIn,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
