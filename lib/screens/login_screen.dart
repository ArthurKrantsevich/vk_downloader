import 'package:flutter/material.dart';

import '../app/app_router.dart';
import '../models/vk_auth_session.dart';
import '../services/vk_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authService,
  });

  final IVkAuthService authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  VkAuthSession? _session;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await widget.authService.currentSession();
    if (!mounted) return;
    setState(() {
      _session = session;
    });
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final session = await widget.authService.authenticate();
      if (!mounted) return;
      setState(() {
        _session = session;
      });
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.download);
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await widget.authService.logout();
      if (!mounted) return;
      setState(() {
        _session = null;
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAuthenticated = _session != null;
    final expirationText = _session == null
        ? null
        : (_session!.expiresIn == 0
            ? 'Токен бессрочный (scope offline).'
            : 'Срок действия до: '
                '${_session!.createdAt.add(Duration(seconds: _session!.expiresIn)).toLocal()}');
    return Scaffold(
      appBar: AppBar(
        title: const Text('VK Login'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connect your VK account',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'В файле lib/services/vk_oauth_config.dart укажите идентификатор '
              'приложения VK и redirect URI (схему надо зарегистрировать на платформах). '
              'После успешной авторизации токен сохранится в Hive для последующего использования.',
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isAuthenticated
                              ? Icons.check_circle_outline
                              : Icons.lock_outline,
                          color: isAuthenticated
                              ? theme.colorScheme.primary
                              : theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isAuthenticated
                              ? 'Вы уже авторизованы'
                              : 'Авторизация не выполнена',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    if (_session != null) ...[
                      const SizedBox(height: 12),
                      Text('User ID: ${_session!.userId}'),
                      if (expirationText != null)
                        Text(
                          expirationText,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : (isAuthenticated ? _logout : _login),
                          icon: Icon(
                            isAuthenticated ? Icons.logout : Icons.login,
                          ),
                          label: Text(
                            isAuthenticated ? 'Выйти' : 'Войти через VK',
                          ),
                        ),
                        if (_isLoading) ...[
                          const SizedBox(width: 16),
                          const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
