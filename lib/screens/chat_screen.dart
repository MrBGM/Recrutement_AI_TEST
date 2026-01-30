import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/message.dart';
import '../models/app_user.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../services/user_service.dart';

/// Écran de conversation entre deux utilisateurs
class ChatScreen extends StatelessWidget {
  final VoidCallback onBack;

  const ChatScreen({super.key, required this.onBack});

  void _showClearDialog(BuildContext context, ChatProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider la discussion'),
        content: const Text('Voulez-vous supprimer tous les messages ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              provider.clearChat();
              Navigator.pop(context);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context,
      ChatProvider provider, String messageId, bool forEveryone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            forEveryone ? 'Supprimer pour tous ?' : 'Supprimer pour vous ?'),
        content: Text(forEveryone
            ? 'Cette action est irréversible. Le message sera supprimé pour tous les participants.'
            : 'Le message ne sera plus visible pour vous, mais restera visible pour ${provider.otherUser.displayName}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (forEveryone) {
                provider.deleteMessageForEveryone(messageId);
              } else {
                provider.deleteMessageForMe(messageId);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(forEveryone
                      ? 'Message supprimé pour tous'
                      : 'Message supprimé pour vous'),
                  backgroundColor: forEveryone ? Colors.red : Colors.blue,
                ),
              );
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, ChatProvider provider,
      String messageId, String currentContent) {
    final controller = TextEditingController(text: currentContent);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Modifiez votre message...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              final newContent = controller.text.trim();
              if (newContent.isNotEmpty && newContent != currentContent) {
                provider.editMessage(messageId, newContent);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Message modifié'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
              Navigator.pop(context);
            },
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  void _replyToMessage(
      BuildContext context, ChatProvider provider, Message message) {
    provider.messageController.text = "@${message.senderName} ";
    provider.messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: provider.messageController.text.length),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Réponse à ${message.senderName}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final otherUser = provider.otherUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isDesktop = screenWidth >= 1024;

    // Sur mobile (pas dans le contexte de ChatsTab split-view), afficher la flèche retour
    // Sur tablet/desktop dans split-view, pas besoin de la flèche retour si la largeur est suffisante
    final showBackButton = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              )
            : null,
        automaticallyImplyLeading: showBackButton,
        title: _buildAppBarTitle(context, otherUser),
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 0,
        toolbarHeight: isDesktop ? 64 : 56,
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, size: isDesktop ? 28 : 24),
            tooltip: 'Vider la discussion',
            onPressed: () => _showClearDialog(context, provider),
          ),
          SizedBox(width: isDesktop ? 8 : 0),
        ],
      ),
      body: Column(
        children: [
          // Affichage des erreurs
          if (provider.error != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isDesktop ? 16 : 12),
              color: colorScheme.errorContainer,
              child: Text(
                provider.error!,
                style: TextStyle(
                  color: colorScheme.onErrorContainer,
                  fontSize: isDesktop ? 15 : 14,
                ),
              ),
            ),

          // Indicateur "en train d'écrire"
          _TypingIndicator(otherUserId: otherUser.id),

          // Liste des messages
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: provider.messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Erreur: ${snapshot.error}'),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: isDesktop ? 80 : 64,
                            color: colorScheme.outline,
                          ),
                          SizedBox(height: isDesktop ? 24 : 16),
                          Text(
                            'Aucun message',
                            style: TextStyle(
                              color: colorScheme.outline,
                              fontSize: isDesktop ? 22 : 18,
                            ),
                          ),
                          SizedBox(height: isDesktop ? 12 : 8),
                          Text(
                            'Dites bonjour à ${otherUser.displayName} !',
                            style: TextStyle(
                              color: colorScheme.outline,
                              fontSize: isDesktop ? 16 : 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: false,
                  padding: EdgeInsets.symmetric(
                    vertical: isDesktop ? 20 : 16,
                    horizontal: isDesktop ? 16 : 0,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return MessageBubble(
                      key: ValueKey(message.id),
                      message: message,
                      isMe: message.senderId == provider.currentUserId,
                      onDeleteForMe: (messageId) =>
                          _showDeleteConfirmationDialog(
                              context, provider, messageId, false),
                      onDeleteForEveryone: (messageId) =>
                          _showDeleteConfirmationDialog(
                              context, provider, messageId, true),
                      onEdit: (messageId, newContent) => _showEditDialog(
                          context, provider, messageId, newContent),
                      onReaction: (messageId, emoji) =>
                          provider.addReaction(messageId, emoji),
                      onSwipeReply: () =>
                          _replyToMessage(context, provider, message),
                    );
                  },
                );
              },
            ),
          ),

          // Zone de saisie
          const ChatInput(),
        ],
      ),
    );
  }

  Widget _buildAppBarTitle(BuildContext context, AppUser otherUser) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final avatarRadius = isDesktop ? 22.0 : 18.0;

    return Row(
      children: [
        // Avatar avec indicateur en ligne
        Stack(
          children: [
            CircleAvatar(
              radius: avatarRadius,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                otherUser.displayName.isNotEmpty
                    ? otherUser.displayName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: isDesktop ? 16 : 14,
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: isDesktop ? 14 : 12,
                height: isDesktop ? 14 : 12,
                decoration: BoxDecoration(
                  color: otherUser.isOnline ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(width: isDesktop ? 16 : 12),
        // Nom et statut
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                otherUser.displayName,
                style: TextStyle(fontSize: isDesktop ? 18 : 16),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                otherUser.isOnline ? 'En ligne' : 'Hors ligne',
                style: TextStyle(
                  fontSize: isDesktop ? 13 : 12,
                  fontWeight: FontWeight.normal,
                  color: otherUser.isOnline
                      ? Colors.green
                      : Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer
                          .withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Indicateur "en train d'écrire..." avec mise à jour en temps réel
class _TypingIndicator extends StatelessWidget {
  final String otherUserId;

  const _TypingIndicator({required this.otherUserId});

  @override
  Widget build(BuildContext context) {
    final userService = UserService();

    return StreamBuilder<AppUser?>(
      // Utiliser getUserStream pour les mises à jour en temps réel
      stream: userService.getUserStream(otherUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final user = snapshot.data!;
        final conversationId = context.read<ChatProvider>().conversationId;

        if (!user.isTypingIn(conversationId)) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[100],
          child: Row(
            children: [
              Text(
                '${user.displayName} est en train d\'écrire',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
