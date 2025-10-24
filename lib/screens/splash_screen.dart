import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_router.dart';
import '../services/vk_auth_service.dart';

abstract class SplashNavigator {
  void openDownload(BuildContext context);
  void openLogin(BuildContext context);
}

class DefaultSplashNavigator implements SplashNavigator {
  const DefaultSplashNavigator();

  @override
  void openDownload(BuildContext context) {
    Navigator.of(context).pushReplacementNamed(AppRoutes.download);
  }

  @override
  void openLogin(BuildContext context) {
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }
}

class SplashScreen extends StatefulWidget {
  SplashScreen({
    super.key,
    SplashNavigator? navigator,
    this.displayDuration = const Duration(seconds: 2),
    required this.authService,
  }) : navigator = navigator ?? const DefaultSplashNavigator();

  final SplashNavigator navigator;
  final Duration displayDuration;
  final IVkAuthService authService;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _timer = Timer(widget.displayDuration, () {
      _handleNavigation();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleNavigation() async {
    if (!mounted) return;
    final isLoggedIn = await widget.authService.isAuthenticated();
    if (!mounted) return;
    if (isLoggedIn) {
      widget.navigator.openDownload(context);
    } else {
      widget.navigator.openLogin(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_download_outlined,
                  size: 96,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(
                  'VK Downloader',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Seamlessly back up your VK albums',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
