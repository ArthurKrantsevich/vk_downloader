import 'package:flutter/material.dart';

import 'features/home/presentation/home_screen.dart';

class VkDownloaderApp extends StatelessWidget {
  const VkDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4C7BFF),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'VK Downloader',
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF2F3F7),
        textTheme: baseTheme.textTheme.apply(
          fontFamily: 'SF Pro Display',
          bodyColor: const Color(0xFF1F2430),
          displayColor: const Color(0xFF1F2430),
        ),
        iconTheme: baseTheme.iconTheme.copyWith(size: 20),
        cardTheme: baseTheme.cardTheme.copyWith(
          color: Colors.white.withOpacity(0.72),
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
            shape: const StadiumBorder(),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
            shape: const StadiumBorder(),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
            shape: const StadiumBorder(),
          ),
        ),
        inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
          hintStyle: const TextStyle(color: Color(0xFF7A8192)),
        ),
        snackBarTheme: baseTheme.snackBarTheme.copyWith(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black.withOpacity(0.85),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentTextStyle: const TextStyle(fontSize: 14),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
