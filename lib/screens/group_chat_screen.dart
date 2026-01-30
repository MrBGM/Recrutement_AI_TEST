import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';
import '../models/group.dart';
import '../models/app_user.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../services/firestore_service.dart';
import '../services/user_service.dart';

/// Écran de conversation de groupe
class GroupChatScreen extends StatefulWidget {
  final Group group;
  final VoidCallback onBack;

  const GroupChatScreen({
    super.key,
    required this.group,
    required this.onBack,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final UserService _userService = UserService();

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => _GroupInfoSheet(
          group: widget.group,
          scrollController: scrollController,
          userService: _userService,
        ),
      ),
    );
  }

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
            ? 'Cette action est irréversible. Le message sera supprimé pour tous les membres du groupe.'
            : 'Le message ne sera plus visible pour vous.'),
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

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Non connecté')),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isDesktop = screenWidth >= 1024;

    // Créer un AppUser factice pour le groupe (pour compatibilité avec ChatProvider)
    final groupAsUser = AppUser(
      id: widget.group.id,
      displayName: widget.group.name,
      email: '',
      isOnline: false,
    );

    return ChangeNotifierProvider(
      key: ValueKey(widget.group.id),
      create: (_) => ChatProvider(
        currentUserId: currentUser.uid,
        currentUserName: currentUser.displayName ?? 'Utilisateur',
        otherUser: groupAsUser,
        isGroupChat: true,
        groupId: widget.group.id,
        groupName: widget.group.name,
      ),
      child: Builder(
        builder: (context) {
          final provider = context.watch<ChatProvider>();

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              toolbarHeight: isDesktop ? 64 : 56,
              title: InkWell(
                onTap: _showGroupInfo,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: isDesktop ? 22 : 18,
                      backgroundColor: colorScheme.secondaryContainer,
                      child: Icon(
                        Icons.groups,
                        size: isDesktop ? 24 : 20,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    SizedBox(width: isDesktop ? 16 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.group.name,
                            style: TextStyle(fontSize: isDesktop ? 18 : 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${widget.group.memberIds.length} membres',
                            style: TextStyle(
                              fontSize: isDesktop ? 13 : 12,
                              fontWeight: FontWeight.normal,
                              color: colorScheme.onPrimaryContainer
                                  .withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              elevation: 0,
              actions: [
                IconButton(
                  icon: Icon(Icons.info_outline, size: isDesktop ? 28 : 24),
                  tooltip: 'Infos du groupe',
                  onPressed: _showGroupInfo,
                ),
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
                                  Icons.groups_outlined,
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
                                  'Commencez la conversation !',
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
                          final isMe =
                              message.senderId == provider.currentUserId;

                          return MessageBubble(
                            key: ValueKey(message.id),
                            message: message,
                            isMe: isMe,
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
                            onSwipeReply: () {},
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
        },
      ),
    );
  }
}

/// Feuille d'informations du groupe
class _GroupInfoSheet extends StatefulWidget {
  final Group group;
  final ScrollController scrollController;
  final UserService userService;

  const _GroupInfoSheet({
    required this.group,
    required this.scrollController,
    required this.userService,
  });

  @override
  State<_GroupInfoSheet> createState() => _GroupInfoSheetState();
}

class _GroupInfoSheetState extends State<_GroupInfoSheet> {
  final FirestoreService _firestoreService = FirestoreService();
  late Group _group;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
  }

  Future<void> _editGroup() async {
    final nameController = TextEditingController(text: _group.name);
    final descController = TextEditingController(text: _group.description ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le groupe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nom du groupe',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.group),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optionnel)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, {
                'name': nameController.text.trim(),
                'description': descController.text.trim(),
              });
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result != null && result['name']!.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await _firestoreService.updateGroup(
          groupId: _group.id,
          name: result['name'],
          description: result['description'],
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Groupe modifie'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addMembers() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // Obtenir tous les utilisateurs
    final allUsers = await widget.userService.getAllUsers(currentUserId).first;

    // Filtrer ceux qui ne sont pas deja membres
    final availableUsers = allUsers
        .where((u) => !_group.memberIds.contains(u.id))
        .toList();

    if (availableUsers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tous les contacts sont deja membres'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final selectedIds = <String>{};

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajouter des membres'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availableUsers.length,
              itemBuilder: (context, index) {
                final user = availableUsers[index];
                final isSelected = selectedIds.contains(user.id);

                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (value) {
                    setDialogState(() {
                      if (value == true) {
                        selectedIds.add(user.id);
                      } else {
                        selectedIds.remove(user.id);
                      }
                    });
                  },
                  title: Text(user.displayName),
                  subtitle: Text(user.isOnline ? 'En ligne' : 'Hors ligne'),
                  secondary: CircleAvatar(
                    child: Text(user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : '?'),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: selectedIds.isNotEmpty
                  ? () => Navigator.pop(context, true)
                  : null,
              child: Text('Ajouter (${selectedIds.length})'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedIds.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await _firestoreService.addMembersToGroup(
          groupId: _group.id,
          memberIds: selectedIds.toList(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${selectedIds.length} membre(s) ajoute(s)'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeMember(String memberId, String memberName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer du groupe'),
        content: Text('Voulez-vous retirer $memberName du groupe ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _firestoreService.removeMemberFromGroup(
          groupId: _group.id,
          memberId: memberId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$memberName retire du groupe'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _leaveGroup() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter le groupe'),
        content: const Text(
          'Voulez-vous vraiment quitter ce groupe ? '
          'Vous ne recevrez plus les messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _firestoreService.removeMemberFromGroup(
          groupId: _group.id,
          memberId: currentUserId,
        );
        if (mounted) {
          Navigator.pop(context); // Fermer la feuille
          Navigator.pop(context); // Retour a la liste
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vous avez quitte le groupe'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleAdmin(String memberId, String memberName, bool makeAdmin) async {
    final action = makeAdmin ? 'promouvoir' : 'retrograder';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(makeAdmin ? 'Promouvoir admin' : 'Retirer admin'),
        content: Text(
          makeAdmin
              ? 'Voulez-vous promouvoir $memberName comme administrateur ?'
              : 'Voulez-vous retirer les droits admin de $memberName ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _firestoreService.toggleGroupAdmin(
          groupId: _group.id,
          memberId: memberId,
          makeAdmin: makeAdmin,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(makeAdmin
                  ? '$memberName est maintenant admin'
                  : '$memberName n\'est plus admin'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isAdmin = _group.adminIds.contains(currentUserId);

    return StreamBuilder<Group?>(
      stream: _firestoreService.getGroupStream(_group.id),
      builder: (context, snapshot) {
        // Mettre a jour le groupe si les donnees changent
        if (snapshot.hasData && snapshot.data != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _group.id == snapshot.data!.id) {
              setState(() => _group = snapshot.data!);
            }
          });
        }

        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: ListView(
                controller: widget.scrollController,
                children: [
                  // Poignee
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outline.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // En-tete du groupe
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: colorScheme.secondaryContainer,
                          child: Icon(
                            Icons.groups,
                            size: 48,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _group.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_group.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          Text(
                            _group.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.outline,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          '${_group.memberIds.length} membres',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(),

                  // Liste des membres
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Membres (${_group.memberIds.length})',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        if (isAdmin)
                          IconButton(
                            icon: const Icon(Icons.person_add),
                            color: Colors.green,
                            onPressed: _addMembers,
                            tooltip: 'Ajouter des membres',
                          ),
                      ],
                    ),
                  ),

                  ..._group.memberIds.map((memberId) {
                    final isMemberAdmin = _group.adminIds.contains(memberId);
                    final isCurrentUser = memberId == currentUserId;

                    return FutureBuilder<AppUser?>(
                      future: widget.userService.getUserById(memberId),
                      builder: (context, snapshot) {
                        final user = snapshot.data;
                        final displayName = user?.displayName ?? 'Utilisateur';
                        final isOnline = user?.isOnline ?? false;

                        return ListTile(
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor: colorScheme.primaryContainer,
                                child: Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isOnline)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: colorScheme.surface,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCurrentUser) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '(vous)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.outline,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            isOnline ? 'En ligne' : 'Hors ligne',
                            style: TextStyle(
                              color: isOnline ? Colors.green : colorScheme.outline,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isMemberAdmin)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Admin',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              // Menu d'actions pour les admins
                              if (isAdmin && !isCurrentUser)
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'toggle_admin':
                                        _toggleAdmin(
                                          memberId,
                                          displayName,
                                          !isMemberAdmin,
                                        );
                                        break;
                                      case 'remove':
                                        _removeMember(memberId, displayName);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'toggle_admin',
                                      child: Row(
                                        children: [
                                          Icon(
                                            isMemberAdmin
                                                ? Icons.remove_moderator
                                                : Icons.add_moderator,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(isMemberAdmin
                                              ? 'Retirer admin'
                                              : 'Promouvoir admin'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: Row(
                                        children: [
                                          Icon(Icons.person_remove,
                                              size: 20, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Retirer du groupe',
                                              style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  }),

                  const SizedBox(height: 24),

                  // Actions
                  if (isAdmin) ...[
                    const Divider(),
                    ListTile(
                      leading: Icon(Icons.edit, color: colorScheme.primary),
                      title: const Text('Modifier le groupe'),
                      onTap: _editGroup,
                    ),
                    ListTile(
                      leading: const Icon(Icons.person_add, color: Colors.green),
                      title: const Text('Ajouter des membres'),
                      onTap: _addMembers,
                    ),
                  ],

                  ListTile(
                    leading: const Icon(Icons.exit_to_app, color: Colors.red),
                    title: const Text(
                      'Quitter le groupe',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: _leaveGroup,
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Indicateur de chargement
            if (_isLoading)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        );
      },
    );
  }
}
