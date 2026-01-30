import 'package:ai_chat/screens/chat_tab.dart';
import 'package:ai_chat/screens/contact_tab.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import 'settings_tab.dart';

/// Écran principal avec navigation à onglets (style WhatsApp)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _setUserOnline();
  }

  @override
  void dispose() {
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _setUserOffline();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.detached) {
        _userService.setUserOffline(user.uid);
      } else if (state == AppLifecycleState.resumed) {
        _userService.setUserOnline(user.uid);
      }
    }
  }

  void _setUserOnline() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userService.setUserOnline(user.uid);
    }
  }

  void _setUserOffline() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userService.setUserOffline(user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isDesktop = screenWidth >= 1024;

    // Sur desktop, on peut utiliser un layout avec NavigationRail
    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // NavigationRail pour desktop
            NavigationRail(
              selectedIndex: _tabController.index,
              onDestinationSelected: (index) {
                setState(() {
                  _tabController.animateTo(index);
                });
              },
              extended: screenWidth >= 1200,
              backgroundColor: colorScheme.primary,
              selectedIconTheme: IconThemeData(color: colorScheme.onPrimary),
              unselectedIconTheme: IconThemeData(color: colorScheme.onPrimary.withOpacity(0.6)),
              selectedLabelTextStyle: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
              unselectedLabelTextStyle: TextStyle(color: colorScheme.onPrimary.withOpacity(0.6)),
              indicatorColor: colorScheme.primaryContainer,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: colorScheme.onPrimary,
                      child: Text(
                        user?.displayName?.isNotEmpty == true
                            ? user!.displayName![0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'AI Chat',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              destinations: [
                NavigationRailDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  selectedIcon: Icon(Icons.chat_bubble),
                  label: Text('Discussions'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.contacts_outlined),
                  selectedIcon: Icon(Icons.contacts),
                  label: Text('Contacts'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Paramètres'),
                ),
              ],
            ),
            // Contenu principal
            Expanded(
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, child) {
                  return IndexedStack(
                    index: _tabController.index,
                    children: const [
                      ChatsTab(),
                      ContactsTab(),
                      SettingsTab(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    // Layout tablette et mobile avec TabBar
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'AI Chat',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 24 : 20,
          ),
        ),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        toolbarHeight: isTablet ? 64 : 56,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.onPrimary,
          indicatorWeight: 3,
          labelColor: colorScheme.onPrimary,
          unselectedLabelColor: colorScheme.onPrimary.withOpacity(0.7),
          labelStyle: TextStyle(fontSize: isTablet ? 14 : 12),
          tabs: [
            Tab(
              icon: Icon(Icons.chat_bubble, size: isTablet ? 28 : 24),
              text: 'Discussions',
            ),
            Tab(
              icon: Icon(Icons.contacts, size: isTablet ? 28 : 24),
              text: 'Contacts',
            ),
            Tab(
              icon: Icon(Icons.settings, size: isTablet ? 28 : 24),
              text: 'Paramètres',
            ),
          ],
        ),
        actions: [
          // Photo de profil utilisateur
          Padding(
            padding: EdgeInsets.only(right: isTablet ? 24 : 16),
            child: CircleAvatar(
              radius: isTablet ? 22 : 18,
              backgroundColor: colorScheme.onPrimary,
              child: Text(
                user?.displayName?.isNotEmpty == true
                    ? user!.displayName![0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: isTablet ? 16 : 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ChatsTab(),
          ContactsTab(),
          SettingsTab(),
        ],
      ),
    );
  }
}
