import 'package:flutter/material.dart';

import '../screens/download_screen.dart';
import '../screens/history_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/splash_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String login = '/login';
  static const String download = '/download';
  static const String history = '/history';
}

class AppRouter {
  const AppRouter();

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _buildRoute(
          settings,
          SplashScreen(),
        );
      case AppRoutes.home:
        return _buildRoute(
          settings,
          const HomeScreen(),
        );
      case AppRoutes.login:
        return _buildRoute(
          settings,
          const LoginScreen(),
        );
      case AppRoutes.download:
        return _buildRoute(
          settings,
          const DownloadScreen(),
        );
      case AppRoutes.history:
        return _buildRoute(
          settings,
          const HistoryScreen(),
        );
      default:
        return _buildRoute(
          settings,
          const Scaffold(
            body: Center(
              child: Text('Route not found'),
            ),
          ),
        );
    }
  }

  PageRouteBuilder<dynamic> _buildRoute(RouteSettings settings, Widget child) {
    return PageRouteBuilder<dynamic>(
      settings: settings,
      pageBuilder: (_, __, ___) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fadeTween = Tween<double>(begin: 0, end: 1).chain(
          CurveTween(curve: Curves.easeInOut),
        );
        return FadeTransition(
          opacity: animation.drive(fadeTween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }
}
