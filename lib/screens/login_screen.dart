import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// Écran de connexion/inscription
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLogin = true; // true = connexion, false = inscription
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLogin) {
        await _authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await _authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width >= 600;
    final isDesktop = screenSize.width >= 1024;

    // Dimensions responsives
    final maxFormWidth = isDesktop ? 450.0 : (isTablet ? 400.0 : double.infinity);
    final horizontalPadding = isDesktop ? 48.0 : (isTablet ? 32.0 : 24.0);
    final logoSize = isDesktop ? 80.0 : (isTablet ? 70.0 : 60.0);
    final titleFontSize = isDesktop ? 40.0 : (isTablet ? 36.0 : 32.0);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer,
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxFormWidth),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Container(
                        padding: EdgeInsets.all(isDesktop ? 24 : 20),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chat_rounded,
                          size: logoSize,
                          color: colorScheme.onPrimary,
                        ),
                      ),

                      SizedBox(height: isDesktop ? 40 : 32),

                      // Titre
                      Text(
                        'AI Chat',
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        _isLogin ? 'Connexion' : 'Inscription',
                        style: TextStyle(
                          fontSize: isTablet ? 20 : 18,
                          color: colorScheme.outline,
                        ),
                      ),

                      SizedBox(height: isDesktop ? 40 : 32),

                      // Message d'erreur
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Champ Nom (uniquement pour inscription)
                      if (!_isLogin) ...[
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Nom',
                            hintText: 'Votre nom ou pseudo',
                            prefixIcon: const Icon(Icons.person_outline),
                            filled: true,
                            fillColor: colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            if (!_isLogin &&
                                (value == null || value.trim().isEmpty)) {
                              return 'Veuillez entrer votre nom';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Champ Email
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'votre@email.com',
                          prefixIcon: const Icon(Icons.email_outlined),
                          filled: true,
                          fillColor: colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Veuillez entrer votre email';
                          }
                          if (!value.contains('@')) {
                            return 'Email invalide';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Champ Mot de passe
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          hintText: 'Min 6 caractères',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        obscureText: _obscurePassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer un mot de passe';
                          }
                          if (value.length < 6) {
                            return 'Min 6 caractères';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: isDesktop ? 32 : 24),

                      // Bouton principal
                      SizedBox(
                        width: double.infinity,
                        height: isDesktop ? 60 : 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _isLogin ? 'Se connecter' : 'S\'inscrire',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 20 : 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Switch connexion/inscription
                      TextButton(
                        onPressed: _toggleMode,
                        child: Text(
                          _isLogin
                              ? 'Pas de compte ? S\'inscrire'
                              : 'Déjà un compte ? Se connecter',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: isTablet ? 16 : 14,
                          ),
                        ),
                      ),

                      SizedBox(height: isDesktop ? 40 : 32),

                      // Info AI
                      Container(
                        padding: EdgeInsets.all(isDesktop ? 20 : 16),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiaryContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text('✨', style: TextStyle(fontSize: isDesktop ? 28 : 24)),
                            SizedBox(width: isDesktop ? 16 : 12),
                            Expanded(
                              child: Text(
                                'Chattez avec vos contacts et utilisez l\'IA pour vous aider à répondre !',
                                style: TextStyle(
                                  color: colorScheme.onTertiaryContainer,
                                  fontSize: isDesktop ? 16 : 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
