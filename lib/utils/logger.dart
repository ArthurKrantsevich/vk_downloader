import 'dart:developer' as developer;

class AppLogger {
  const AppLogger._();

  static void info(String message, {String name = 'VKDownloader'}) {
    developer.log(message, name: name, level: 800);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace, String name = 'VKDownloader'}) {
    developer.log(
      message,
      name: name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
