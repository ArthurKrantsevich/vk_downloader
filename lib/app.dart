import 'package:flutter/material.dart';
import 'features/home/presentation/home_screen.dart';

class VkDownloaderApp extends StatelessWidget {
  const VkDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4C7BFF),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
    );

    final theme = base.copyWith(
      // Backgrounds
      scaffoldBackgroundColor: const Color(0xFFF6F7FA),

      // Colors
      colorScheme: base.colorScheme.copyWith(
        surface: Colors.white,
        onSurface: const Color(0xFF15181E),
        secondaryContainer: Colors.white.withOpacity(0.80),
      ),

      // Text
      textTheme: base.textTheme.apply(
        fontFamily: 'SF Pro Display',
        bodyColor: const Color(0xFF15181E),
        displayColor: const Color(0xFF15181E),
      ),

      // AppBar — clean, flat, centered, no purple haze on scroll
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        toolbarHeight: 56,
        titleTextStyle: TextStyle(
          fontFamily: 'SF Pro Display',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF15181E),
        ),
        iconTheme: IconThemeData(
          color: Color(0xFF15181E),
          size: 20,
        ),
      ),

      // Cards — soft corners, no heavy tints/shadows
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      ),

      // Inputs — subtle filled, no outlines
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFFF0F2F6),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
      ),

      // Buttons — tactile sizes, consistent typography
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF4C7BFF),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF4C7BFF), width: 1.3),
          foregroundColor: const Color(0xFF4C7BFF),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      // Small polishers
      dividerTheme: const DividerThemeData(
        color: Color(0x1A000000), // subtle hairline
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black.withOpacity(0.88),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentTextStyle: const TextStyle(
          fontFamily: 'SF Pro Display',
          fontSize: 14,
          color: Colors.white,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: const TextStyle(
          fontFamily: 'SF Pro Display',
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.88),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: const TextStyle(
          fontFamily: 'SF Pro Display',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF15181E),
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'SF Pro Display',
          fontSize: 14,
          color: Color(0xFF15181E),
        ),
      ),

      // Consistent iOS-like transitions on desktop too
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      ),

      // Selection colors for a coherent text experience
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Color(0xFF4C7BFF),
        selectionColor: Color(0x334C7BFF),
        selectionHandleColor: Color(0xFF4C7BFF),
      ),
    );

    return MaterialApp(
      title: 'VK Downloader',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const HomeScreen(),
    );
  }
}
