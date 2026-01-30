import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

/// Onglet Paramètres avec profil et options
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  void _showEditProfileDialog(AppUser? appUser) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final nameController = TextEditingController(
      text: appUser?.displayName ?? user.displayName ?? '',
    );
    final statusController = TextEditingController(
      text: appUser?.status ?? '',
    );

    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifier le profil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom d\'affichage',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                enabled: !isLoading,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: statusController,
                decoration: const InputDecoration(
                  labelText: 'Statut (bio)',
                  hintText: 'Disponible, Occupé, En réunion...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info_outline),
                ),
                maxLines: 2,
                enabled: !isLoading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final newName = nameController.text.trim();
                      final newStatus = statusController.text.trim();

                      if (newName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Le nom ne peut pas être vide'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isLoading = true);

                      try {
                        // Mettre à jour Firebase Auth
                        await user.updateDisplayName(newName);

                        // Mettre à jour Firestore
                        await _userService.updateUserProfile(
                          userId: user.uid,
                          displayName: newName,
                          status: newStatus,
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profil mis à jour avec succès'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          setState(() {});
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _authService.signOut();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isDesktop = screenWidth >= 1024;

    if (user == null) {
      return const Center(child: Text('Non connecté'));
    }

    // Dimensions responsives
    final headerPadding = isDesktop ? 40.0 : (isTablet ? 32.0 : 24.0);
    final avatarRadius = isDesktop ? 80.0 : (isTablet ? 70.0 : 60.0);
    final nameFontSize = isDesktop ? 32.0 : (isTablet ? 28.0 : 24.0);
    final avatarFontSize = isDesktop ? 64.0 : (isTablet ? 56.0 : 48.0);

    return StreamBuilder<AppUser?>(
      stream: _userService.getUserStream(user.uid),
      builder: (context, snapshot) {
        final appUser = snapshot.data;
        final displayName = appUser?.displayName ?? user.displayName ?? 'Utilisateur';
        final status = appUser?.status;

        Widget content = ListView(
          children: [
            // Header avec photo de profil
            Container(
              padding: EdgeInsets.all(headerPadding),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  // Photo de profil
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: avatarRadius,
                        backgroundColor: colorScheme.onPrimary,
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: avatarFontSize,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: isDesktop ? 24 : 18,
                          backgroundColor: colorScheme.primary,
                          child: IconButton(
                            icon: Icon(
                              Icons.camera_alt,
                              size: isDesktop ? 24 : 18,
                              color: colorScheme.onPrimary,
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Fonctionnalité à venir'),
                                ),
                              );
                            },
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: isDesktop ? 24 : 16),

                  // Nom
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: nameFontSize,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimary,
                    ),
                  ),

                  // Statut/Bio
                  if (status != null && status.isNotEmpty) ...[
                    SizedBox(height: isDesktop ? 8 : 4),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: isDesktop ? 16 : 14,
                        color: colorScheme.onPrimary.withOpacity(0.9),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  SizedBox(height: isDesktop ? 8 : 4),

                  // Email
                  Text(
                    user.email ?? '',
                    style: TextStyle(
                      fontSize: isDesktop ? 16 : 14,
                      color: colorScheme.onPrimary.withOpacity(0.8),
                    ),
                  ),

                  SizedBox(height: isDesktop ? 24 : 16),

                  // Bouton modifier
                  OutlinedButton.icon(
                    onPressed: () => _showEditProfileDialog(appUser),
                    icon: const Icon(Icons.edit),
                    label: const Text('Modifier le profil'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.onPrimary,
                      side: BorderSide(color: colorScheme.onPrimary),
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 24 : 16,
                        vertical: isDesktop ? 16 : 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: isDesktop ? 16 : 8),

            // Section Compte
            _SectionHeader(title: 'Compte'),
            _SettingsTile(
              icon: Icons.person_outline,
              title: 'Informations personnelles',
              subtitle: status?.isNotEmpty == true ? status! : 'Nom, bio, photo',
              onTap: () => _showEditProfileDialog(appUser),
            ),
            _SettingsTile(
              icon: Icons.security_outlined,
              title: 'Confidentialité',
              subtitle: 'Qui peut voir mes infos',
              onTap: () {},
            ),

            const Divider(height: 1),

            // Section Notifications
            _SectionHeader(title: 'Notifications'),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications push',
              subtitle: 'Messages, appels, groupes',
              trailing: Switch(
                value: true,
                onChanged: (value) {},
              ),
            ),
            _SettingsTile(
              icon: Icons.volume_up_outlined,
              title: 'Sons',
              subtitle: 'Sons de notification',
              onTap: () {},
            ),

            const Divider(height: 1),

            // Section Apparence
            _SectionHeader(title: 'Apparence'),
            _SettingsTile(
              icon: Icons.palette_outlined,
              title: 'Thème',
              subtitle: 'Clair, sombre, auto',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.wallpaper_outlined,
              title: 'Fond d\'écran',
              subtitle: 'Personnaliser l\'arrière-plan',
              onTap: () {},
            ),

            const Divider(height: 1),

            // Section Stockage
            _SectionHeader(title: 'Stockage et données'),
            _SettingsTile(
              icon: Icons.storage_outlined,
              title: 'Gestion du stockage',
              subtitle: 'Gérer les médias et fichiers',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.wifi_outlined,
              title: 'Utilisation des données',
              subtitle: 'Téléchargement automatique',
              onTap: () {},
            ),

            const Divider(height: 1),

            // Section Aide
            _SectionHeader(title: 'Aide'),
            _SettingsTile(
              icon: Icons.help_outline,
              title: 'Centre d\'aide',
              subtitle: 'FAQ et support',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.info_outline,
              title: 'À propos',
              subtitle: 'Version 2.0.0',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'AI Chat',
                  applicationVersion: '2.0.0',
                  applicationIcon: Icon(Icons.chat_bubble, size: isDesktop ? 64 : 48),
                  children: [
                    const Text('Application de messagerie avec IA'),
                    const SizedBox(height: 8),
                    const Text('© 2026 - Tous droits réservés'),
                  ],
                );
              },
            ),

            const Divider(height: 1),

            // Bouton déconnexion
            SizedBox(height: isDesktop ? 24 : 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16),
              child: OutlinedButton.icon(
                onPressed: _showLogoutDialog,
                icon: const Icon(Icons.logout),
                label: const Text('Déconnexion'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: EdgeInsets.symmetric(vertical: isDesktop ? 20 : 16),
                ),
              ),
            ),

            SizedBox(height: isDesktop ? 48 : 32),
          ],
        );

        // Sur desktop, centrer le contenu avec une largeur max
        if (isDesktop) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: content,
            ),
          );
        }

        return content;
      },
    );
  }
}

/// Header de section
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Tuile de paramètre
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
