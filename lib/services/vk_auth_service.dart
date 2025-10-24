import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/vk_auth_session.dart';
import 'vk_oauth_config.dart';

abstract class IVkAuthService {
  Future<VkAuthSession?> authenticate();
  Future<void> logout();
  Future<bool> isAuthenticated();
  Future<VkAuthSession?> currentSession();
}

class VkAuthService implements IVkAuthService {
  VkAuthService({
    required VkOAuthConfig config,
    HiveInterface? hive,
    DateTime Function()? clock,
  })  : _config = config,
        _hive = hive ?? Hive,
        _clock = clock ?? DateTime.now;

  static const String _boxName = 'vk_auth_box';
  static const String _sessionKey = 'session';
  static final VkAuthSessionAdapter _adapter = VkAuthSessionAdapter();

  final VkOAuthConfig _config;
  final HiveInterface _hive;
  final DateTime Function() _clock;
  Box<VkAuthSession>? _box;

  Future<Box<VkAuthSession>> _ensureBox() async {
    if (_box != null) {
      return _box!;
    }
    if (!_hive.isAdapterRegistered(_adapter.typeId)) {
      _hive.registerAdapter(_adapter);
    }
    if (!_hive.isBoxOpen(_boxName)) {
      _box = await _hive.openBox<VkAuthSession>(_boxName);
    } else {
      _box = _hive.box<VkAuthSession>(_boxName);
    }
    return _box!;
  }

  @override
  Future<VkAuthSession?> authenticate() async {
    _assertConfig();
    final box = await _ensureBox();
    final state = _clock().millisecondsSinceEpoch.toString();
    final authUri = _config.buildAuthorizationUri(state: state);
    final result = await FlutterWebAuth2.authenticate(
      url: authUri.toString(),
      callbackUrlScheme: _config.redirectScheme,
    );
    final redirected = Uri.parse(result);
    final params = _parseFragment(redirected.fragment);
    if (params['state'] != null && params['state'] != state) {
      throw StateError('VK OAuth state mismatch.');
    }
    final session = VkAuthSession(
      accessToken: params['access_token'] ?? '',
      userId: params['user_id'] ?? '',
      expiresIn: int.tryParse(params['expires_in'] ?? '') ?? 0,
      createdAt: _clock(),
    );
    if (session.accessToken.isEmpty || session.userId.isEmpty) {
      throw StateError('VK OAuth did not return a valid session.');
    }
    await box.put(_sessionKey, session);
    return session;
  }

  @override
  Future<VkAuthSession?> currentSession() async {
    final box = await _ensureBox();
    return box.get(_sessionKey);
  }

  @override
  Future<bool> isAuthenticated() async {
    final session = await currentSession();
    if (session == null) {
      return false;
    }
    final expired = session.isExpired && session.expiresIn != 0;
    if (expired) {
      await logout();
      return false;
    }
    return true;
  }

  @override
  Future<void> logout() async {
    final box = await _ensureBox();
    await box.delete(_sessionKey);
  }

  Map<String, String> _parseFragment(String fragment) {
    if (fragment.isEmpty) {
      return <String, String>{};
    }
    return fragment
        .split('&')
        .map((pair) => pair.split('='))
        .where((pair) => pair.length == 2)
        .map((pair) => MapEntry(
              Uri.decodeComponent(pair[0]),
              Uri.decodeComponent(pair[1]),
            ))
        .fold<Map<String, String>>(<String, String>{}, (acc, entry) {
      acc[entry.key] = entry.value;
      return acc;
    });
  }

  void _assertConfig() {
    if (_config.clientId.isEmpty ||
        _config.clientId.contains('REPLACE_WITH_CLIENT_ID')) {
      throw StateError(
        'VK OAuth config is not configured. Update defaultVkOAuthConfig before authenticating.',
      );
    }
    if (_config.redirectUri.isEmpty) {
      throw StateError('VK OAuth redirect URI is empty.');
    }
  }
}
