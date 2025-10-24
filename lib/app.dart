import 'package:flutter/material.dart';

import 'features/home/presentation/home_screen.dart';

class VkDownloaderApp extends StatelessWidget {
  const VkDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VK Downloader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0077FF)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
