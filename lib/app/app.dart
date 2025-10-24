import 'package:flutter/material.dart';

import 'app_router.dart';

class VkDownloaderApp extends StatelessWidget {
  VkDownloaderApp({super.key});

  final AppRouter _router = const AppRouter();

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
