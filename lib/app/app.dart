import 'package:flutter/material.dart';

import '../services/vk_auth_service.dart';
import 'app_router.dart';

class VkDownloaderApp extends StatelessWidget {
  VkDownloaderApp({
    super.key,
    required IVkAuthService authService,
  }) : _router = AppRouter(authService: authService);

  final AppRouter _router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VK Downloader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)),
        useMaterial3: true,
        textTheme: Theme.of(context).textTheme.apply(
              fontFamily: 'Roboto',
            ),
      ),
      initialRoute: AppRoutes.splash,
      onGenerateRoute: _router.onGenerateRoute,
    );
  }
}
