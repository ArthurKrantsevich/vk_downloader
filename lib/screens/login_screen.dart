import 'package:flutter/material.dart';

import '../app/app_router.dart';
import '../models/vk_auth_session.dart';
import '../services/vk_auth_service.dart';
import '../services/vk_oauth_config.dart';

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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _clientIdController;
  late final TextEditingController _redirectUriController;
  late final TextEditingController _scopesController;
  bool _configLoaded = false;

  @override
  void initState() {
    super.initState();
    final initialConfig = widget.authService.config;
    _clientIdController =
        TextEditingController(text: _sanitizeClientId(initialConfig.clientId));
    _redirectUriController =
        TextEditingController(text: initialConfig.redirectUri);
    _scopesController =
        TextEditingController(text: initialConfig.scopes.join(', '));
    _loadSession();
    _loadConfig();
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _redirectUriController.dispose();
    _scopesController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final session = await widget.authService.currentSession();
    if (!mounted) return;
    setState(() {
      _session = session;
    });
  }

  Future<void> _loadConfig() async {
    final config = await widget.authService.loadSavedConfig();
    if (!mounted) return;
    _clientIdController.text = _sanitizeClientId(config.clientId);
    _redirectUriController.text = config.redirectUri;
    _scopesController.text = config.scopes.join(', ');
    setState(() {
      _configLoaded = true;
    });
  }

  String _sanitizeClientId(String value) {
    if (value.contains('REPLACE_WITH_CLIENT_ID')) {
      return '';
    }
    return value;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final scopes = _parseScopes(_scopesController.text);
      final updatedConfig = VkOAuthConfig(
        clientId: _clientIdController.text.trim(),
        redirectUri: _redirectUriController.text.trim(),
        scopes: scopes.isEmpty
            ? widget.authService.config.scopes
            : scopes,
        apiVersion: widget.authService.config.apiVersion,
      );
      await widget.authService.updateConfig(updatedConfig);
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

  List<String> _parseScopes(String raw) {
    return raw
        .split(',')
        .map((scope) => scope.trim())
        .where((scope) => scope.isNotEmpty)
        .toList();
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
              'Подключите свой аккаунт VK',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Укажите данные вашего приложения VK, чтобы открыть стандартную форму '
              'авторизации. После входа токен сохранится и вы сможете загружать '
              'альбомы прямо из своего профиля.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Card(
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
                            Icons.app_registration,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Данные приложения VK',
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _clientIdController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'ID приложения',
                          hintText: 'Например, 51548352',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Введите идентификатор приложения VK';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _redirectUriController,
                        decoration: const InputDecoration(
                          labelText: 'Redirect URI',
                          hintText: 'vk1234567://auth',
                          prefixIcon: Icon(Icons.link_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Укажите redirect URI из настроек приложения VK';
                          }
                          final uri = Uri.tryParse(value.trim());
                          if (uri == null || !uri.hasScheme) {
                            return 'Введите корректный URI со схемой (например, vk123://auth)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _scopesController,
                        decoration: const InputDecoration(
                          labelText: 'Права доступа (scope)',
                          hintText: 'offline, photos, video',
                          prefixIcon: Icon(Icons.vpn_key_outlined),
                          helperText:
                              'Укажите через запятую необходимые разрешения VK API.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Подсказка по настройке:'),
                              SizedBox(height: 6),
                              Text(
                                '1. Создайте Standalone-приложение на vk.com/dev.\n'
                                '2. Добавьте тот же redirect URI в настройках платформ.\n'
                                '3. Выберите нужные права доступа и сохраните их здесь.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: _isLoading
                                ? null
                                : (isAuthenticated ? _logout : _login),
                            icon: Icon(
                              isAuthenticated ? Icons.logout : Icons.login,
                            ),
                            label: Text(
                              isAuthenticated
                                  ? 'Выйти из VK'
                                  : 'Открыть форму VK',
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
            ),
            const SizedBox(height: 16),
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
                    if (!_configLoaded) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: const [
                          SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Загружаем сохранённые настройки...'),
                        ],
                      ),
                    ],
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
