import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../core/persistence/preferences_store.dart';
import '../../../core/persistence/secure_storage_client.dart';
import '../domain/media_filter.dart';
import '../domain/media_item.dart';
import '../domain/media_url_normalizer.dart';
import 'home_state.dart';
import 'media_download_service.dart';

const _kStoredCookiesKey = 'vk_webview_cookies';
const _kStoredUserInfoKey = 'vk_user_info';
const _kPrefsVisitedKey = 'prefs_visited_urls';
const _kPrefsSidePanelKey = 'prefs_side_panel_visible';
const _kPrefsSearchKey = 'prefs_media_search';
const _initialUrl = 'https://vk.com';

class BulkDownloadSummary {
  const BulkDownloadSummary({
    required this.completed,
    required this.total,
    required this.canceled,
  });

  final int completed;
  final int total;
  final bool canceled;
}

class HomeController extends ChangeNotifier {
  HomeController({
    required PreferencesStore preferences,
    required SecureStorageClient secureStorage,
    required MediaFilter mediaFilter,
    required MediaUrlNormalizer urlNormalizer,
    required MediaDownloadService downloadService,
    this.onLog,
  }) : _preferences = preferences,
       _secureStorage = secureStorage,
       _mediaFilter = mediaFilter,
       _urlNormalizer = urlNormalizer,
       _downloadService = downloadService;

  final PreferencesStore _preferences;
  final SecureStorageClient _secureStorage;
  final MediaFilter _mediaFilter;
  final MediaUrlNormalizer _urlNormalizer;
  final MediaDownloadService _downloadService;
  final void Function(String message)? onLog;

  HomeState _state = HomeState.initial();

  HomeState get state => _state;

  InAppWebViewController? webViewController;

  final Map<String, Uint8List?> _thumbnailCache = {};

  bool _bulkCancelRequested = false;
  Map<String, dynamic> _prefsCache = {};
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _restoreCookies();
    await _restoreUserInfo();
    await _restorePreferences();
  }

  Future<void> _restoreCookies() async {
    _log('restoreCookies: start');
    try {
      final cookies = await _secureStorage.readJsonList(_kStoredCookiesKey);
      if (cookies == null || cookies.isEmpty) {
        _log('restoreCookies: nothing');
        return;
      }
      int restored = 0;
      for (final cookie in cookies) {
        final domain = (cookie['domain'] as String?) ?? '';
        if (domain.isEmpty) continue;
        final host = domain.startsWith('.') ? domain.substring(1) : domain;
        await CookieManager.instance().setCookie(
          url: WebUri('https://$host'),
          name: (cookie['name'] as String?) ?? '',
          value: (cookie['value'] as String?) ?? '',
          domain: domain,
          path: (cookie['path'] as String?) ?? '/',
          expiresDate: cookie['expires'] as int?,
          isSecure: (cookie['isSecure'] as bool?) ?? false,
          isHttpOnly: (cookie['isHttpOnly'] as bool?) ?? false,
        );
        restored++;
      }
      _log('restoreCookies: restored $restored');
    } catch (error, stackTrace) {
      _log('restoreCookies error: $error\n$stackTrace');
    }
  }

  Future<void> _restoreUserInfo() async {
    try {
      final json = await _secureStorage.readJson(_kStoredUserInfoKey);
      if (json == null || json.isEmpty) return;
      final info = <String, String>{};
      json.forEach((key, value) {
        if (value == null) return;
        final str = '$value'.trim();
        if (str.isNotEmpty) info[key] = str;
      });
      if (info.isEmpty) return;
      _emit(state.copyWith(userInfo: Map.unmodifiable(info)));
      _log('restoreUserInfo: ${info.keys.join(', ')}');
    } catch (error, stackTrace) {
      _log('restoreUserInfo error: $error\n$stackTrace');
    }
  }

  Future<void> _restorePreferences() async {
    _prefsCache = await _preferences.read();
    final visited =
        (_prefsCache[_kPrefsVisitedKey] as List?)?.cast<String>() ??
        const <String>[];
    final storedSearch = (_prefsCache[_kPrefsSearchKey] as String?) ?? '';
    final isSidePanelVisible =
        (_prefsCache[_kPrefsSidePanelKey] as bool?) ?? true;
    final urls = visited.isNotEmpty ? visited : const <String>[_initialUrl];
    _emit(
      state.copyWith(
        visitedUrls: List.unmodifiable(urls),
        mediaSearch: storedSearch,
        isSidePanelVisible: isSidePanelVisible,
      ),
    );
  }

  void updateWebViewController(InAppWebViewController controller) {
    webViewController = controller;
  }

  void _emit(HomeState newState) {
    _state = HomeState(
      currentUrl: newState.currentUrl,
      visitedUrls: List.unmodifiable(newState.visitedUrls),
      events: List.unmodifiable(newState.events),
      mediaItems: List.unmodifiable(newState.mediaItems),
      selectedMedia: Set.unmodifiable(newState.selectedMedia),
      userInfo: Map.unmodifiable(newState.userInfo),
      isSidePanelVisible: newState.isSidePanelVisible,
      mediaSearch: newState.mediaSearch,
      isBulkDownloading: newState.isBulkDownloading,
      bulkDownloadTotal: newState.bulkDownloadTotal,
      bulkDownloadProcessed: newState.bulkDownloadProcessed,
      bulkDownloadSucceeded: newState.bulkDownloadSucceeded,
      isBulkCancelRequested: newState.isBulkCancelRequested,
    );
    notifyListeners();
  }

  void _log(String message) {
    final events = List<String>.from(state.events)..add(message);
    _emit(state.copyWith(events: events));
    onLog?.call(message);
    if (kDebugMode) {
      // ignore: avoid_print
      print(message);
    }
  }

  void updateCurrentUrl(String url) {
    if (url.isEmpty) return;
    final visited = List<String>.from(state.visitedUrls);
    visited.remove(url);
    visited.add(url);
    if (visited.length > 100) {
      visited.removeRange(0, visited.length - 100);
    }
    _emit(state.copyWith(currentUrl: url, visitedUrls: visited));
    _persistVisitedUrls();
  }

  void recordHistory(String url) {
    updateCurrentUrl(url);
  }

  void setSidePanelVisible(bool value) {
    if (state.isSidePanelVisible == value) return;
    _emit(state.copyWith(isSidePanelVisible: value));
    _prefsCache[_kPrefsSidePanelKey] = value;
    _persistPreferences();
  }

  void updateMediaSearch(String value) {
    if (state.mediaSearch == value) return;
    _emit(state.copyWith(mediaSearch: value));
    _prefsCache[_kPrefsSearchKey] = value;
    _persistPreferences();
  }

  void replaceMedia(List<String> rawUrls) {
    final filtered = rawUrls
        .map((url) => _urlNormalizer.normalize(url))
        .where(_mediaFilter.isRelevant)
        .toSet()
        .toList(growable: false);
    final mediaItems = filtered
        .map(
          (url) => MediaItem(
            originalUrl: url,
            normalizedUrl: url,
            thumbnail: _thumbnailCache[url],
          ),
        )
        .toList(growable: false);
    _thumbnailCache.removeWhere((key, _) => !filtered.contains(key));
    _emit(state.copyWith(mediaItems: mediaItems, selectedMedia: <String>{}));
    _log('mediaHandler: raw=${rawUrls.length}, filtered=${mediaItems.length}');
  }

  void toggleSelection(String url, bool value) {
    final updated = Set<String>.from(state.selectedMedia);
    if (value) {
      updated.add(url);
    } else {
      updated.remove(url);
    }
    _emit(state.copyWith(selectedMedia: updated));
  }

  void selectAll(Iterable<String> urls) {
    final updated = Set<String>.from(state.selectedMedia);
    for (final url in urls) {
      final item = state.mediaItems.firstWhere(
        (element) => element.normalizedUrl == url,
        orElse: () => MediaItem(originalUrl: url, normalizedUrl: url),
      );
      if (!item.isStream) {
        updated.add(url);
      }
    }
    _emit(state.copyWith(selectedMedia: updated));
  }

  void clearSelections() {
    if (state.selectedMedia.isEmpty) return;
    _emit(state.copyWith(selectedMedia: <String>{}));
  }

  bool clearMedia() {
    if (state.mediaItems.isEmpty) {
      return false;
    }
    _thumbnailCache.clear();
    _emit(
      state.copyWith(
        mediaItems: const <MediaItem>[],
        selectedMedia: <String>{},
      ),
    );
    _log('media list cleared');
    return true;
  }

  Future<void> saveCookiesForUrl(String url) async {
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri(url),
      );
      if (cookies.isEmpty) {
        _log('saveCookies: none for $url');
        return;
      }
      final list = cookies
          .map(
            (cookie) => {
              'name': cookie.name,
              'value': cookie.value,
              'domain': cookie.domain,
              'path': cookie.path ?? '/',
              'expires': cookie.expiresDate,
              'isSecure': cookie.isSecure ?? false,
              'isHttpOnly': cookie.isHttpOnly ?? false,
            },
          )
          .toList();
      await _secureStorage.writeJsonList(_kStoredCookiesKey, list);
      _log('saveCookies: ${list.length} cookies');
    } catch (error, stackTrace) {
      _log('saveCookies error: $error\n$stackTrace');
    }
  }

  Future<void> refreshUserInfo() async {
    final controller = webViewController;
    if (controller == null) return;
    try {
      final result = await controller.evaluateJavascript(
        source: '''
        (function(){
          try {
            const vkObj = window?.vk || window?.VK || {};
            const id = vkObj.id || vkObj.userId || null;
            let name = null;
            const nameEl = document.querySelector('#top_profile_link .top_profile_name')
              || document.querySelector('#top_profile_link')
              || document.querySelector('[class*="TopNavBtn__profileName"]');
            if (nameEl) {
              name = (nameEl.textContent || '').trim();
            }
            let avatar = null;
            const avatarEl = document.querySelector('#top_profile_link img')
              || document.querySelector('[class*="TopNavBtn__profileImg"] img')
              || document.querySelector('img.TopNavBtn__profileImg');
            if (avatarEl && avatarEl.src) {
              avatar = avatarEl.src;
            }
            if (!id && !name && !avatar) return null;
            return { id: id, name: name, avatar: avatar };
          } catch(e) { return null; }
        })();
      ''',
      );
      if (result is Map) {
        final info = <String, String>{};
        result.forEach((key, value) {
          if (value == null) return;
          final str = '$value'.trim();
          if (str.isNotEmpty) {
            info['$key'] = str;
          }
        });
        if (info.isNotEmpty && info.toString() != state.userInfo.toString()) {
          await _secureStorage.writeJson(_kStoredUserInfoKey, info);
          _emit(state.copyWith(userInfo: Map.unmodifiable(info)));
          _log('saveUserInfo: ${info.keys.join(', ')}');
        }
      }
    } catch (error, stackTrace) {
      _log('userInfo eval error: $error\n$stackTrace');
    }
  }

  Future<BulkDownloadSummary> downloadSelectedMedia() async {
    if (state.selectedMedia.isEmpty || state.isBulkDownloading) {
      return const BulkDownloadSummary(completed: 0, total: 0, canceled: false);
    }
    final urls = state.selectedMedia.toList(growable: false);
    _bulkCancelRequested = false;
    _emit(
      state.copyWith(
        isBulkDownloading: true,
        bulkDownloadTotal: urls.length,
        bulkDownloadProcessed: 0,
        bulkDownloadSucceeded: 0,
        isBulkCancelRequested: false,
      ),
    );
    var succeeded = 0;
    var processed = 0;
    final downloaded = <String>[];
    final referer = state.currentUrl.isEmpty
        ? 'https://vk.com/'
        : state.currentUrl;
    var canceled = false;
    for (var index = 0; index < urls.length; index++) {
      if (_bulkCancelRequested) {
        canceled = true;
        break;
      }
      final url = urls[index];
      final path = await _downloadService.downloadToDisk(url, referer);
      processed++;
      final success = path != null;
      if (success) {
        succeeded++;
        downloaded.add(url);
      }
      _emit(
        state.copyWith(
          bulkDownloadProcessed: processed,
          bulkDownloadSucceeded: succeeded,
          isBulkCancelRequested: _bulkCancelRequested,
        ),
      );
      if (_bulkCancelRequested) {
        canceled = true;
        break;
      }
      if ((index + 1) % 5 == 0 && index + 1 < urls.length) {
        for (var delay = 0; delay < 2 && !_bulkCancelRequested; delay++) {
          await Future.delayed(const Duration(seconds: 2));
        }
        if (_bulkCancelRequested) {
          canceled = true;
          break;
        }
      }
    }
    final remainingSelected = Set<String>.from(state.selectedMedia);
    for (final url in downloaded) {
      remainingSelected.remove(url);
    }
    _emit(
      state.copyWith(
        isBulkDownloading: false,
        bulkDownloadTotal: 0,
        bulkDownloadProcessed: 0,
        bulkDownloadSucceeded: 0,
        selectedMedia: remainingSelected,
        isBulkCancelRequested: false,
      ),
    );
    _bulkCancelRequested = false;
    return BulkDownloadSummary(
      completed: succeeded,
      total: urls.length,
      canceled: canceled,
    );
  }

  Future<String?> downloadSingleMedia(String url) async {
    final referer = state.currentUrl.isEmpty
        ? 'https://vk.com/'
        : state.currentUrl;
    return _downloadService.downloadToDisk(url, referer);
  }

  void cancelBulkDownload() {
    if (!state.isBulkDownloading) return;
    _bulkCancelRequested = true;
    _emit(state.copyWith(isBulkCancelRequested: true));
  }

  void addEvent(String message) => _log(message);

  Future<Uint8List?> thumbnailFor(String url) async {
    if (_thumbnailCache.containsKey(url)) {
      return _thumbnailCache[url];
    }
    final referer = state.currentUrl.isEmpty
        ? 'https://vk.com/'
        : state.currentUrl;
    final bytes = await _downloadService.loadThumbnail(url, referer);
    _thumbnailCache[url] = bytes;
    return bytes;
  }

  Future<void> _persistVisitedUrls() async {
    _prefsCache[_kPrefsVisitedKey] = state.visitedUrls.take(100).toList();
    await _persistPreferences();
  }

  Future<void> _persistPreferences() async {
    await _preferences.write(_prefsCache);
  }
}
