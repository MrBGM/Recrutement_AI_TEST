import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../models/conversation.dart';
import '../services/firestore_service.dart';
import '../services/user_service.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';
import 'group_chat_screen.dart';
import '../models/group.dart';

/// Type de selection dans la liste des conversations
enum _SelectionType { user, group }

/// Onglet Discussions avec liste de conversations et chat côte à côte
class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  final UserService _userService = UserService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  AppUser? _selectedUser;
  Group? _selectedGroup;
  _SelectionType? _selectionType;
  String? _currentUserId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  void _selectUser(AppUser user) {
    setState(() {
      _selectedUser = user;
      _selectedGroup = null;
      _selectionType = _SelectionType.user;
    });
  }

  void _selectGroup(Group group) {
    setState(() {
      _selectedGroup = group;
      _selectedUser = null;
      _selectionType = _SelectionType.group;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedUser = null;
      _selectedGroup = null;
      _selectionType = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = FirebaseAuth.instance.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isDesktop = screenWidth >= 1024;
    final isMobile = screenWidth < 600;

    if (currentUser == null) {
      return const Center(child: Text('Non connecte'));
    }

    // Calcul des dimensions responsives
    final sidebarWidth = isDesktop ? 380.0 : (isTablet ? 320.0 : screenWidth);

    // Sur mobile, afficher soit la liste soit le chat (pas les deux)
    if (isMobile) {
      if (_selectionType == null) {
        return _buildConversationsList(context, currentUser, screenWidth);
      } else if (_selectionType == _SelectionType.user && _selectedUser != null) {
        return ChangeNotifierProvider(
          key: ValueKey(_selectedUser!.id),
          create: (_) => ChatProvider(
            currentUserId: currentUser.uid,
            currentUserName: currentUser.displayName ?? 'Utilisateur',
            otherUser: _selectedUser!,
          ),
          child: ChatScreen(
            onBack: _clearSelection,
          ),
        );
      } else if (_selectionType == _SelectionType.group && _selectedGroup != null) {
        return GroupChatScreen(
          group: _selectedGroup!,
          onBack: _clearSelection,
        );
      }
    }

    // Sur tablette et desktop, afficher le split-view
    return Row(
      children: [
        // ========================================
        // BARRE LATERALE GAUCHE - LISTE DES CONVERSATIONS
        // ========================================
        Container(
          width: sidebarWidth,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              right: BorderSide(
                color: colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          child: _buildConversationsList(context, currentUser, sidebarWidth),
        ),

        // ========================================
        // ZONE PRINCIPALE - CONVERSATION
        // ========================================
        Expanded(
          child: _buildMainContent(currentUser),
        ),
      ],
    );
  }

  Widget _buildMainContent(User currentUser) {
    if (_selectionType == null) {
      return _buildEmptyState(context);
    }

    if (_selectionType == _SelectionType.user && _selectedUser != null) {
      return ChangeNotifierProvider(
        key: ValueKey(_selectedUser!.id),
        create: (_) => ChatProvider(
          currentUserId: currentUser.uid,
          currentUserName: currentUser.displayName ?? 'Utilisateur',
          otherUser: _selectedUser!,
        ),
        child: ChatScreen(
          onBack: _clearSelection,
        ),
      );
    }

    if (_selectionType == _SelectionType.group && _selectedGroup != null) {
      return GroupChatScreen(
        key: ValueKey(_selectedGroup!.id),
        group: _selectedGroup!,
        onBack: _clearSelection,
      );
    }

    return _buildEmptyState(context);
  }

  Widget _buildConversationsList(BuildContext context, User currentUser, double width) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = width >= 380;

    return Column(
      children: [
        // Header de recherche
        Container(
          padding: EdgeInsets.all(isDesktop ? 16 : 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant,
              ),
            ),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher conversation ou groupe...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: colorScheme.surfaceContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 16 : 12,
                vertical: 12,
              ),
            ),
          ),
        ),

        // Liste combinee: Groupes + Conversations individuelles
        Expanded(
          child: _buildCombinedList(context, currentUser, isDesktop),
        ),
      ],
    );
  }

  Widget _buildCombinedList(BuildContext context, User currentUser, bool isDesktop) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<Group>>(
      stream: _firestoreService.getUserGroups(currentUser.uid),
      builder: (context, groupsSnapshot) {
        return StreamBuilder<List<AppUser>>(
          stream: _userService.getAllUsers(currentUser.uid),
          builder: (context, usersSnapshot) {
            if (groupsSnapshot.connectionState == ConnectionState.waiting &&
                usersSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final groups = groupsSnapshot.data ?? [];
            final users = usersSnapshot.data ?? [];

            // Filtrer par recherche
            final filteredGroups = _searchQuery.isEmpty
                ? groups
                : groups.where((g) => g.name.toLowerCase().contains(_searchQuery)).toList();

            final filteredUsers = _searchQuery.isEmpty
                ? users
                : users.where((u) => u.displayName.toLowerCase().contains(_searchQuery)).toList();

            if (filteredGroups.isEmpty && filteredUsers.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isNotEmpty
                            ? Icons.search_off
                            : Icons.chat_bubble_outline,
                        size: isDesktop ? 72 : 64,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Aucun resultat pour "$_searchQuery"'
                            : 'Aucune conversation',
                        style: TextStyle(
                          color: colorScheme.outline,
                          fontSize: isDesktop ? 18 : 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView(
              children: [
                // Section Groupes
                if (filteredGroups.isNotEmpty) ...[
                  _buildSectionHeader(
                    context,
                    'Groupes',
                    filteredGroups.length,
                    Icons.groups,
                    isDesktop,
                  ),
                  ...filteredGroups.map((group) => _GroupConversationTile(
                        group: group,
                        currentUserId: currentUser.uid,
                        isSelected: _selectedGroup?.id == group.id,
                        onTap: () => _selectGroup(group),
                        isDesktop: isDesktop,
                      )),
                  const SizedBox(height: 8),
                ],

                // Section Conversations individuelles
                if (filteredUsers.isNotEmpty) ...[
                  _buildSectionHeader(
                    context,
                    'Conversations',
                    filteredUsers.length,
                    Icons.person,
                    isDesktop,
                  ),
                  ...filteredUsers.map((user) {
                    final conversationId = _firestoreService.getConversationId(
                        currentUser.uid, user.id);
                    return _ConversationTile(
                      user: user,
                      conversationId: conversationId,
                      currentUserId: currentUser.uid,
                      isSelected: _selectedUser?.id == user.id,
                      onTap: () => _selectUser(user),
                    );
                  }),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    int count,
    IconData icon,
    bool isDesktop,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 16,
        vertical: isDesktop ? 12 : 10,
      ),
      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
      child: Row(
        children: [
          Icon(
            icon,
            size: isDesktop ? 20 : 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: TextStyle(
              fontSize: isDesktop ? 14 : 13,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Container(
      color: colorScheme.surfaceContainerLow,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: isDesktop ? 140 : 120,
                color: colorScheme.outline.withOpacity(0.3),
              ),
              SizedBox(height: isDesktop ? 32 : 24),
              Text(
                'Sélectionnez une conversation',
                style: TextStyle(
                  fontSize: isDesktop ? 28 : 24,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isDesktop ? 12 : 8),
              Text(
                'Choisissez un contact dans la liste pour commencer à discuter',
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 14,
                  color: colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tuile representant une conversation avec compteur non lus
class _ConversationTile extends StatelessWidget {
  final AppUser user;
  final String conversationId;
  final String currentUserId;
  final bool isSelected;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.user,
    required this.conversationId,
    required this.currentUserId,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final firestoreService = FirestoreService();
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return StreamBuilder<Conversation?>(
      stream: firestoreService.getConversationStream(conversationId),
      builder: (context, snapshot) {
        final conversation = snapshot.data;
        final unreadCount = conversation?.getUnreadCount(currentUserId) ?? 0;
        final hasUnread = unreadCount > 0;

        // Tailles responsives
        final avatarRadius = isDesktop ? 32.0 : 28.0;
        final nameFontSize = isDesktop ? 17.0 : 16.0;
        final messageFontSize = isDesktop ? 15.0 : 14.0;
        final horizontalPadding = isDesktop ? 20.0 : 16.0;
        final verticalPadding = isDesktop ? 14.0 : 12.0;

        return Material(
          color:
              isSelected ? colorScheme.secondaryContainer : Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant.withOpacity(0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Avatar avec statut
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: avatarRadius,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: isDesktop ? 20 : 18,
                          ),
                        ),
                      ),
                      // Indicateur en ligne
                      if (user.isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: isDesktop ? 16 : 14,
                            height: isDesktop ? 16 : 14,
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

                  SizedBox(width: isDesktop ? 16 : 12),

                  // Infos conversation
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nom
                        Text(
                          user.displayName,
                          style: TextStyle(
                            fontWeight:
                                hasUnread ? FontWeight.bold : FontWeight.w600,
                            fontSize: nameFontSize,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        SizedBox(height: isDesktop ? 6 : 4),

                        // Dernier message ou statut
                        Text(
                          conversation?.lastMessage ?? 'Aucun message',
                          style: TextStyle(
                            fontSize: messageFontSize,
                            color: hasUnread
                                ? colorScheme.onSurface
                                : colorScheme.outline,
                            fontWeight:
                                hasUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Badge compteur non lus
                  if (hasUnread)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 10 : 8,
                        vertical: isDesktop ? 5 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: isDesktop ? 13 : 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Tuile representant un groupe dans la liste des conversations
class _GroupConversationTile extends StatelessWidget {
  final Group group;
  final String currentUserId;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDesktop;

  const _GroupConversationTile({
    required this.group,
    required this.currentUserId,
    required this.isSelected,
    required this.onTap,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unreadCount = group.getUnreadCount(currentUserId);
    final hasUnread = unreadCount > 0;

    // Tailles responsives
    final avatarRadius = isDesktop ? 32.0 : 28.0;
    final nameFontSize = isDesktop ? 17.0 : 16.0;
    final messageFontSize = isDesktop ? 15.0 : 14.0;
    final horizontalPadding = isDesktop ? 20.0 : 16.0;
    final verticalPadding = isDesktop ? 14.0 : 12.0;

    return Material(
      color: isSelected ? colorScheme.secondaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withOpacity(0.3),
              ),
            ),
          ),
          child: Row(
            children: [
              // Avatar du groupe
              Stack(
                children: [
                  CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor: colorScheme.tertiaryContainer,
                    child: Icon(
                      Icons.groups,
                      color: colorScheme.onTertiaryContainer,
                      size: isDesktop ? 28 : 24,
                    ),
                  ),
                  // Badge non lus
                  if (hasUnread)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        decoration: BoxDecoration(
                          color: colorScheme.error,
                          shape: unreadCount > 9 ? BoxShape.rectangle : BoxShape.circle,
                          borderRadius: unreadCount > 9 ? BorderRadius.circular(10) : null,
                        ),
                        child: Center(
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: TextStyle(
                              color: colorScheme.onError,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              SizedBox(width: isDesktop ? 16 : 12),

              // Infos groupe
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom du groupe
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: TextStyle(
                              fontWeight:
                                  hasUnread ? FontWeight.bold : FontWeight.w600,
                              fontSize: nameFontSize,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (group.lastMessageTime != null)
                          Text(
                            _formatTime(group.lastMessageTime!),
                            style: TextStyle(
                              fontSize: 12,
                              color: hasUnread
                                  ? colorScheme.primary
                                  : colorScheme.outline,
                              fontWeight:
                                  hasUnread ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                      ],
                    ),

                    SizedBox(height: isDesktop ? 6 : 4),

                    // Dernier message ou nombre de membres
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.lastMessage ?? '${group.memberIds.length} membres',
                            style: TextStyle(
                              fontSize: messageFontSize,
                              color: hasUnread
                                  ? colorScheme.onSurface
                                  : colorScheme.outline,
                              fontWeight:
                                  hasUnread ? FontWeight.w500 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: colorScheme.outline,
                          size: isDesktop ? 22 : 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Maintenant';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min';
    } else if (difference.inHours < 24 && time.day == now.day) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1 || time.day == now.day - 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      const days = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
      return days[time.weekday % 7];
    } else {
      return '${time.day}/${time.month}';
    }
  }
}
