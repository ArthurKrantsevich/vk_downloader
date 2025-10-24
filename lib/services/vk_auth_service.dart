import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/vk_auth_session.dart';
import 'vk_oauth_config.dart';

abstract class IVkAuthService {
  Future<VkAuthSession?> authenticate();
  Future<void> logout();
  Future<bool> isAuthenticated();
  Future<VkAuthSession?> currentSession();
  VkOAuthConfig get config;
  Future<VkOAuthConfig> loadSavedConfig();
  Future<void> updateConfig(VkOAuthConfig config);
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
  static const String _configBoxName = 'vk_oauth_config_box';
  static const String _configClientIdKey = 'client_id';
  static const String _configRedirectUriKey = 'redirect_uri';
  static const String _configScopesKey = 'scopes';
  static const String _configApiVersionKey = 'api_version';

  VkOAuthConfig _config;
  final HiveInterface _hive;
  final DateTime Function() _clock;
  Box<VkAuthSession>? _box;
  Box<dynamic>? _configBox;

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

  Future<Box<dynamic>> _ensureConfigBox() async {
    if (_configBox != null) {
      return _configBox!;
    }
    if (!_hive.isBoxOpen(_configBoxName)) {
      _configBox = await _hive.openBox<dynamic>(_configBoxName);
    } else {
      _configBox = _hive.box<dynamic>(_configBoxName);
    }
    return _configBox!;
  }

  @override
  VkOAuthConfig get config => _config;

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

  @override
  Future<VkOAuthConfig> loadSavedConfig() async {
    final box = await _ensureConfigBox();
    final storedClientId = box.get(_configClientIdKey) as String?;
    final storedRedirectUri = box.get(_configRedirectUriKey) as String?;
    final storedScopesRaw = box.get(_configScopesKey);
    final storedApiVersion = box.get(_configApiVersionKey) as String?;

    if (storedClientId == null || storedClientId.isEmpty) {
      return _config;
    }

    final scopes = storedScopesRaw is List
        ? storedScopesRaw.whereType<String>().toList()
        : _config.scopes;

    final loadedConfig = VkOAuthConfig(
      clientId: storedClientId,
      redirectUri: storedRedirectUri?.isNotEmpty == true
          ? storedRedirectUri!
          : _config.redirectUri,
      scopes: scopes.isNotEmpty ? scopes : _config.scopes,
      apiVersion: storedApiVersion?.isNotEmpty == true
          ? storedApiVersion!
          : _config.apiVersion,
    );

    _config = loadedConfig;
    return _config;
  }

  @override
  Future<void> updateConfig(VkOAuthConfig config) async {
    final box = await _ensureConfigBox();
    await box.put(_configClientIdKey, config.clientId);
    await box.put(_configRedirectUriKey, config.redirectUri);
    await box.put(_configScopesKey, config.scopes);
    await box.put(_configApiVersionKey, config.apiVersion);
    _config = config;
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
