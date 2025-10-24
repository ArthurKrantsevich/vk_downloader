import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageClient {
  const SecureStorageClient({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<Map<String, dynamic>?> readJson(String key) async {
    final text = await _storage.read(key: key);
    if (text == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry('$k', v));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> readJsonList(String key) async {
    final text = await _storage.read(key: key);
    if (text == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((map) => map.map((k, v) => MapEntry('$k', v)))
            .toList();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeJson(String key, Map<String, dynamic> value) async {
    await _storage.write(key: key, value: jsonEncode(value));
  }

  Future<void> writeJsonList(
    String key,
    List<Map<String, dynamic>> value,
  ) async {
    await _storage.write(key: key, value: jsonEncode(value));
  }
}
