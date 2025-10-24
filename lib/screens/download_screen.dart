import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;

import '../app/app_router.dart';
import '../models/vk_auth_session.dart';
import '../services/vk_auth_service.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({
    super.key,
    required this.authService,
  });

  final IVkAuthService authService;

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  VkAuthSession? _session;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSession();
    });
  }

  Future<void> _loadSession() async {
    setState(() {
      _isLoading = true;
    });
    final isAuthenticated = await widget.authService.isAuthenticated();
    if (!mounted) return;
    if (!isAuthenticated) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      return;
    }
    final session = await widget.authService.currentSession();
    if (!mounted) return;
    setState(() {
      _session = session;
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
    });
    await widget.authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Albums'),
        actions: [
          IconButton(
            tooltip: 'Выйти из VK',
            onPressed: _isLoading ? null : _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_session != null)
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
                            Text(
                              'Текущая сессия',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text('User ID: ${_session!.userId}'),
                            if (_session!.expiresIn > 0)
                              Text(
                                'Токен истекает: '
                                '${_session!.createdAt.add(Duration(seconds: _session!.expiresIn)).toLocal()}',
                              )
                            else
                              const Text('Токен бессрочный (scope offline).'),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Album selection and download management UI goes here.',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
    );
  }
}
