import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/chat_provider.dart';
import '../services/firestore_service.dart';

/// Zone de saisie avec bouton envoyer et bouton AI ✨
class ChatInput extends StatefulWidget {
  const ChatInput({super.key});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isTyping = false;

  void _handleTextChange(String text, ChatProvider provider) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Mettre à jour le statut "en train d'écrire"
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      _firestoreService.setTypingStatus(
        conversationId: provider.conversationId,
        userId: currentUser.uid,
        isTyping: true,
      );
    } else if (text.isEmpty && _isTyping) {
      _isTyping = false;
      _firestoreService.setTypingStatus(
        conversationId: provider.conversationId,
        userId: currentUser.uid,
        isTyping: false,
      );
    }
  }

  void _handleSend(ChatProvider provider) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Arrêter le statut "en train d'écrire"
    if (_isTyping) {
      _isTyping = false;
      _firestoreService.setTypingStatus(
        conversationId: provider.conversationId,
        userId: currentUser.uid,
        isTyping: false,
      );
    }

    // Envoyer le message
    provider.sendMessage();
  }

  @override
  void dispose() {
    // S'assurer qu'on arrête le statut "en train d'écrire" quand on quitte
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && _isTyping) {
      // Note: Ceci peut ne pas fonctionner correctement si le provider n'est plus disponible
      _isTyping = false;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isDesktop = screenWidth >= 1024;

    // Dimensions responsives
    final containerPadding = isDesktop ? 16.0 : 12.0;
    final buttonSpacing = isDesktop ? 12.0 : 8.0;
    final inputVerticalPadding = isDesktop ? 16.0 : 12.0;
    final inputHorizontalPadding = isDesktop ? 20.0 : 16.0;

    return Container(
      padding: EdgeInsets.all(containerPadding),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: isDesktop ? 12 : 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Bouton AI ✨
            _AIButton(
              isLoading: provider.isAILoading,
              onPressed: provider.handleAIButton,
            ),

            SizedBox(width: buttonSpacing),

            // Champ de saisie
            Expanded(
              child: TextField(
                controller: provider.messageController,
                onChanged: (text) => _handleTextChange(text, provider),
                decoration: InputDecoration(
                  hintText: 'Écrire un message...',
                  hintStyle: TextStyle(fontSize: isDesktop ? 16 : 14),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: inputHorizontalPadding,
                    vertical: inputVerticalPadding,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(isDesktop ? 28 : 24),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(fontSize: isDesktop ? 16 : 14),
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(provider),
              ),
            ),

            SizedBox(width: buttonSpacing),

            // Bouton envoyer
            IconButton(
              onPressed: () => _handleSend(provider),
              icon: Icon(
                Icons.send_rounded,
                color: colorScheme.primary,
                size: isDesktop ? 28 : 24,
              ),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.primaryContainer,
                padding: EdgeInsets.all(isDesktop ? 12 : 8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton AI avec animation de chargement
class _AIButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _AIButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 16 : 12,
            vertical: isDesktop ? 12 : 8,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.tertiary,
                colorScheme.primary,
              ],
            ),
            borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
          ),
          child: isLoading
              ? SizedBox(
                  width: isDesktop ? 24 : 20,
                  height: isDesktop ? 24 : 20,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '✨',
                      style: TextStyle(fontSize: isDesktop ? 20 : 16),
                    ),
                    SizedBox(width: isDesktop ? 6 : 4),
                    Text(
                      'AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isDesktop ? 16 : 14,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
