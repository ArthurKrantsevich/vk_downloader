// lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

final _secureStorage = const FlutterSecureStorage();
const _kStoredCookiesKey = 'vk_webview_cookies';
const _kStoredUserInfoKey = 'vk_user_info';
const _kPrefsVisitedKey = 'prefs_visited_urls';
const _kPrefsSidePanelKey = 'prefs_side_panel_visible';
const _kPrefsSearchKey = 'prefs_media_search';
const _uaWebLike =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _initialUrl = 'https://vk.com';

  final TextEditingController _urlCtrl = TextEditingController(text: _initialUrl);
  final TextEditingController _mediaSearchCtrl = TextEditingController();
  final List<String> _visitedUrls = <String>[_initialUrl];
  final List<String> _events = <String>[];
  final List<String> _mediaUrlsRaw = <String>[];   // как пришло из страницы
  final Map<String, Uint8List?> _thumbCache = {};  // кэш превью
  final Set<String> _selectedMedia = <String>{};
  final ScrollController _mediaScrollController = ScrollController();
  final ScrollController _visitedScrollController = ScrollController();
  final ScrollController _eventsScrollController = ScrollController();
  Map<String, String> _userInfo = {};

  InAppWebViewController? _controller;
  InAppWebViewSettings _settings = InAppWebViewSettings(
    javaScriptEnabled: true,
    allowsInlineMediaPlayback: true,
    mediaPlaybackRequiresUserGesture: false,
    isInspectable: true,
  );

  // --- заменяем SharedPreferences на файлик JSON ---
  File? _prefsFile;
  Map<String, dynamic> _prefsCache = {};

  bool _isSidePanelVisible = true;
  String _mediaSearch = '';
  bool _isBulkDownloading = false;
  bool _bulkCancelRequested = false;
  int _bulkDownloadTotal = 0;
  int _bulkDownloadProcessed = 0;
  int _bulkDownloadSucceeded = 0;

  bool get _isDesktop =>
      !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux);

  void _log(String s) {
    setState(() => _events.add(s));
    _scheduleScrollToBottom(_eventsScrollController);
    // ignore: avoid_print
    print(s);
  }

  @override
  void initState() {
    super.initState();
    _restoreCookiesOnStart();
    _restoreUserInfo();
    _initPreferences();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _mediaSearchCtrl.dispose();
    _mediaScrollController.dispose();
    _visitedScrollController.dispose();
    _eventsScrollController.dispose();
    super.dispose();
  }

  // -------------------- Cookies --------------------

  Future<void> _restoreCookiesOnStart() async {
    _log('restoreCookies: start');
    try {
      final jsonStr = await _secureStorage.read(key: _kStoredCookiesKey);
      if (jsonStr == null) {
        _log('restoreCookies: nothing');
        return;
      }
      final list = (jsonDecode(jsonStr) as List).cast<Map>();
      int restored = 0;
      for (final m in list) {
        final domain = (m['domain'] as String?) ?? '';
        if (domain.isEmpty) continue;
        final host = domain.startsWith('.') ? domain.substring(1) : domain;
        await CookieManager.instance().setCookie(
          url: WebUri('https://$host'),
          name: (m['name'] as String?) ?? '',
          value: (m['value'] as String?) ?? '',
          domain: domain,
          path: (m['path'] as String?) ?? '/',
          expiresDate: m['expires'] as int?,
          isSecure: (m['isSecure'] as bool?) ?? false,
          isHttpOnly: (m['isHttpOnly'] as bool?) ?? false,
        );
        restored++;
      }
      _log('restoreCookies: restored $restored');
    } catch (e, st) {
      _log('restoreCookies error: $e\n$st');
    }
  }

  Future<void> _restoreUserInfo() async {
    try {
      final jsonStr = await _secureStorage.read(key: _kStoredUserInfoKey);
      if (jsonStr == null) return;
      final map = Map<String, dynamic>.from(jsonDecode(jsonStr) as Map);
      final info = <String, String>{};
      map.forEach((key, value) {
        if (value == null) return;
        final str = '$value'.trim();
        if (str.isNotEmpty) info[key] = str;
      });
      if (info.isEmpty) return;
      setState(() => _userInfo = info);
      _log('restoreUserInfo: ${info.keys.join(', ')}');
    } catch (e, st) {
      _log('restoreUserInfo error: $e\n$st');
    }
  }

  Future<void> _saveUserInfo(Map<String, String> info) async {
    if (info.isEmpty) return;
    setState(() => _userInfo = Map<String, String>.from(info));
    try {
      await _secureStorage.write(key: _kStoredUserInfoKey, value: jsonEncode(info));
      _log('saveUserInfo: ${info.keys.join(', ')}');
    } catch (e, st) {
      _log('saveUserInfo error: $e\n$st');
    }
  }

  // -------------------- Prefs (JSON в Documents) --------------------

  Future<void> _initPreferences() async {
    final docs = await getApplicationDocumentsDirectory();
    _prefsFile = File('${docs.path}${Platform.pathSeparator}vk_downloader_prefs.json');
    if (await _prefsFile!.exists()) {
      try {
        final txt = await _prefsFile!.readAsString();
        _prefsCache = (jsonDecode(txt) as Map).map((k, v) => MapEntry('$k', v));
      } catch (_) {
        _prefsCache = {};
      }
    }
    final storedVisited = (_prefsCache[_kPrefsVisitedKey] as List?)?.cast<String>() ?? const <String>[];
    final storedSearch = (_prefsCache[_kPrefsSearchKey] as String?) ?? '';
    setState(() {
      _isSidePanelVisible = (_prefsCache[_kPrefsSidePanelKey] as bool?) ?? true;
      if (storedVisited.isNotEmpty) {
        _visitedUrls
          ..clear()
          ..addAll(storedVisited);
      }
      if (_visitedUrls.isEmpty) {
        _visitedUrls.add(_initialUrl);
      }
      _mediaSearch = storedSearch;
      _mediaSearchCtrl.text = storedSearch;
    });
  }

  Future<void> _savePrefs() async {
    try {
      if (_prefsFile == null) return;
      _prefsCache[_kPrefsVisitedKey] = _visitedUrls.take(100).toList(growable: false);
      _prefsCache[_kPrefsSidePanelKey] = _isSidePanelVisible;
      _prefsCache[_kPrefsSearchKey] = _mediaSearch;
      await _prefsFile!.writeAsString(jsonEncode(_prefsCache), flush: true);
    } catch (_) {
      // игнорируем ошибки записи
    }
  }

  Future<void> _persistVisitedUrls() async {
    await _savePrefs();
  }

  void _scheduleScrollToBottom(ScrollController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients) return;
      controller.animateTo(
        controller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _setSidePanelVisible(bool value) {
    if (_isSidePanelVisible == value) return;
    setState(() => _isSidePanelVisible = value);
    unawaited(_savePrefs());
  }

  void _updateMediaSearch(String value) {
    if (_mediaSearch == value) return;
    setState(() => _mediaSearch = value);
    unawaited(_savePrefs());
  }

  void _toggleMediaSelection(String url, bool value) {
    setState(() {
      if (value) {
        _selectedMedia.add(url);
      } else {
        _selectedMedia.remove(url);
      }
    });
  }

  void _selectAllMedia(Iterable<String> urls) {
    setState(() {
      for (final url in urls) {
        if (_isStreamUrl(url)) continue;
        _selectedMedia.add(url);
      }
    });
  }

  void _clearAllSelections() {
    if (_selectedMedia.isEmpty) return;
    setState(() => _selectedMedia.clear());
  }

  void _requestStopBulkDownload() {
    if (!_isBulkDownloading || _bulkCancelRequested) return;
    setState(() => _bulkCancelRequested = true);
  }

  void _clearFoundMedia(BuildContext context) {
    if (_mediaUrlsRaw.isEmpty) return;
    setState(() {
      _mediaUrlsRaw.clear();
      _thumbCache.clear();
      _selectedMedia.clear();
    });
    _log('media list cleared');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cleared media list')),
      );
    }
  }

  Future<void> _downloadSelectedMedia(BuildContext context) async {
    if (_selectedMedia.isEmpty || _isBulkDownloading) return;
    final urls = _selectedMedia.toList(growable: false);
    setState(() {
      _isBulkDownloading = true;
      _bulkCancelRequested = false;
      _bulkDownloadTotal = urls.length;
      _bulkDownloadProcessed = 0;
      _bulkDownloadSucceeded = 0;
    });
    final downloaded = <String>[];
    final total = urls.length;
    var canceled = false;
    for (var i = 0; i < urls.length; i++) {
      if (_bulkCancelRequested) {
        canceled = true;
        break;
      }
      final url = urls[i];
      final path = await _downloadToDisk(url);
      if (!mounted) return;
      final success = path != null;
      setState(() {
        _bulkDownloadProcessed++;
        if (success) {
          _bulkDownloadSucceeded++;
        }
      });
      if (success) {
        downloaded.add(url);
      }
      if (_bulkCancelRequested) {
        canceled = true;
        break;
      }
      if ((i + 1) % 5 == 0 && i + 1 < total) {
        for (var s = 0; s < 2 && !_bulkCancelRequested; s++) {
          await Future.delayed(const Duration(seconds: 1));
        }
        if (_bulkCancelRequested) {
          canceled = true;
          break;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _isBulkDownloading = false;
      _bulkCancelRequested = false;
      _bulkDownloadTotal = 0;
      _bulkDownloadProcessed = 0;
      _bulkDownloadSucceeded = 0;
      for (final url in downloaded) {
        _selectedMedia.remove(url);
      }
    });
    final success = downloaded.length;
    final failed = total - success;
    final msg = canceled
        ? 'Stopped after $success of $total files'
        : (failed == 0
            ? 'Downloaded $success files'
            : 'Downloaded $success of $total files');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _tryUpdateUserInfo() async {
    if (_controller == null) return;
    try {
      final res = await _controller!.evaluateJavascript(source: '''
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
      ''');
      if (res is Map) {
        final info = <String, String>{};
        res.forEach((key, value) {
          if (value == null) return;
          final str = '$value'.trim();
          if (str.isNotEmpty) {
            info['$key'] = str;
          }
        });
        if (info.isNotEmpty && info.toString() != _userInfo.toString()) {
          await _saveUserInfo(info);
        }
      }
    } catch (e, st) {
      _log('userInfo eval error: $e\n$st');
    }
  }

  Future<void> _saveCookiesForUrl(String url) async {
    try {
      final cookies = await CookieManager.instance().getCookies(url: WebUri(url));
      if (cookies.isEmpty) {
        _log('saveCookies: none for $url');
        return;
      }
      final list = cookies
          .map((c) => {
        'name': c.name,
        'value': c.value,
        'domain': c.domain,
        'path': c.path ?? '/',
        'expires': c.expiresDate,
        'isSecure': c.isSecure ?? false,
        'isHttpOnly': c.isHttpOnly ?? false,
      })
          .toList();
      await _secureStorage.write(key: _kStoredCookiesKey, value: jsonEncode(list));
      _log('saveCookies: ${list.length} cookies');
    } catch (e, st) {
      _log('saveCookies error: $e\n$st');
    }
  }

  // -------------------- VK image upscaler (normalize) --------------------

  bool _isHttpUrl(String u) => u.startsWith('http://') || u.startsWith('https://');

  // апгрейдим миниатюры userapi/vkuserphotos -> наибольший размер из as=..., убираем u=, правим cs=Wx0
  String _vkNormalizeImageUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      if (!(host.contains('userapi.com') || host.contains('vkuserphotos'))) {
        return url; // не vk cdn
      }
      final qpAll = Map<String, List<String>>.from(uri.queryParametersAll);
      // вытащим as= "32x21,48x32,...,1280x853"
      final asList =
      (qpAll['as']?.isNotEmpty ?? false) ? qpAll['as']!.first.split(',') : <String>[];
      int maxW = 0;
      for (final s in asList) {
        final parts = s.split('x');
        if (parts.isEmpty) continue;
        final w = int.tryParse(parts.first) ?? 0;
        if (w > maxW) maxW = w;
      }
      if (maxW <= 0) {
        // fallback как в твоём примере
        maxW = 1280;
      }

      // правим cs=... -> "${maxW}x0"
      qpAll['cs'] = ['${maxW}x0'];

      // убираем мусорный u=
      qpAll.remove('u');

      // собираем query обратно (оставляя остальные параметры)
      final flat = <String, String>{};
      for (final e in qpAll.entries) {
        if (e.value.isEmpty) continue;
        flat[e.key] = e.value.first;
      }

      final rebuilt = uri.replace(queryParameters: flat);
      return rebuilt.toString();
    } catch (_) {
      return url;
    }
  }

  // нормализуем ПЕРЕД использованием (превью/скачивание/открытие)
  String _hq(String url) => _vkNormalizeImageUrl(url);

  // -------------------- Media extraction --------------------

  bool _isRelevantMediaUrl(String url) {
    if (!_isHttpUrl(url)) return false;
    final lower = url.toLowerCase();
    const blockedFragments = ['data:image', 'blank.html', 'favicon', 'adsstatic'];
    if (blockedFragments.any(lower.contains)) {
      return false;
    }
    const allowedExts = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.bmp',
      '.mp4',
      '.mov',
      '.m4v',
      '.webm',
      '.m3u8',
    ];
    final hasExt = allowedExts.any(lower.contains);
    final uri = Uri.tryParse(url);
    final host = uri?.host.toLowerCase() ?? '';
    const hostHints = [
      'vk.com',
      'userapi.com',
      'vkuserphotos',
      'vk-cdn',
      'vkvideo',
      'vkuservideo',
      'vkuserlive',
      'vkuseraudio',
    ];
    final matchesHost = hostHints.any(host.contains);
    if (matchesHost && hasExt) return true;
    if (matchesHost &&
        (lower.contains('video_files') || lower.contains('photo.php') || lower.contains('photo-'))) {
      return true;
    }
    return hasExt;
  }

  bool _isStreamUrl(String url) => url.toLowerCase().endsWith('.m3u8');

  bool _isVideoFile(String url) {
    return RegExp(r'\.(mp4|mov|m4v|webm)(\?|$)', caseSensitive: false).hasMatch(url);
  }

  Future<void> _extractMediaFromPage() async {
    if (_controller == null) return;
    try {
      final res = await _controller!.evaluateJavascript(source: '''
        (function(){
          try {
            const imgs = Array.from(document.querySelectorAll('img')).map(i => i.src).filter(Boolean);
            const vids = Array.from(document.querySelectorAll('video')).map(v => v.src).filter(Boolean);
            const srcs = Array.from(document.querySelectorAll('video source')).map(s => s.src).filter(Boolean);
            const links = Array.from(document.querySelectorAll('a')).map(a => a.href).filter(Boolean);
            const vkLinks = links.filter(h => /photo|video|cdn|vkuserphotos|vkontakte|userapi/.test(h));
            const all = [...imgs, ...vids, ...srcs, ...vkLinks];
            const uniq = Array.from(new Set(all));
            window.flutter_inappwebview.callHandler('mediaHandler', uniq);
            return uniq.length;
          } catch(e) { return 0; }
        })();
      ''');
      _log('extractMedia: $res found (raw)');
      // cookies обновим на всякий случай
      if (_urlCtrl.text.isNotEmpty) {
        await _saveCookiesForUrl(_urlCtrl.text);
      }
    } catch (e, st) {
      _log('extractMedia error: $e\n$st');
    }
  }

  // -------------------- HTTP helpers --------------------

  Map<String, String> _headersFor(String url) {
    final referer = _urlCtrl.text.isNotEmpty ? _urlCtrl.text : 'https://vk.com/';
    return {
      HttpHeaders.userAgentHeader: _uaWebLike,
      HttpHeaders.refererHeader: referer,
      HttpHeaders.acceptHeader:
      'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    };
  }

  String _extFromMime(String mime, {String fallback = 'bin'}) {
    final m = mime.toLowerCase();
    if (m.contains('jpeg')) return 'jpg';
    if (m.contains('png')) return 'png';
    if (m.contains('gif')) return 'gif';
    if (m.contains('webp')) return 'webp';
    if (m.contains('bmp')) return 'bmp';
    if (m.contains('svg')) return 'svg';
    if (m.contains('mp4')) return 'mp4';
    if (m.contains('mpeg')) return 'mpg';
    if (m.contains('quicktime')) return 'mov';
    if (m.contains('x-mpegurl') || m.contains('vnd.apple.mpegurl') || m.contains('hls') || m.contains('m3u8')) {
      return 'm3u8';
    }
    return fallback;
  }

  Future<_DownloadResult> _fetch(String url) async {
    final uri = Uri.parse(url);
    final client = HttpClient()..userAgent = _uaWebLike;
    try {
      final req = await client.getUrl(uri);
      _headersFor(url).forEach(req.headers.set);
      final resp = await req.close();
      final mime = resp.headers.contentType?.mimeType ?? '';
      final bytes = await consolidateHttpClientResponseBytes(resp);
      return _DownloadResult(
        ok: resp.statusCode == 200,
        status: resp.statusCode,
        contentType: mime,
        bytes: bytes,
      );
    } finally {
      client.close();
    }
  }

  Future<String?> _downloadToDisk(String url0) async {
    final url = _hq(url0);
    try {
      final res = await _fetch(url);
      if (!res.ok) {
        _log('download: HTTP ${res.status} for $url');
        return null;
      }
      final mime = res.contentType ?? '';
      final isStream = mime.contains('m3u8') || url.toLowerCase().endsWith('.m3u8');
      if (isStream) {
        _log('download: HLS manifest (.m3u8) — поток, не файл MP4');
        return null;
      }

      final ext = _extFromMime(mime, fallback: _guessExtFromUrl(url));
      final dir = await _ensureDownloadDirectory();
      final base = _sanitizeFileName(_basenameFromUrl(url));
      final file = await _createUniqueFile(dir, base, ext);
      await file.writeAsBytes(res.bytes!, flush: true);
      _log('download: saved ${file.path} (${mime.isEmpty ? "unknown" : mime})');
      return file.path;
    } catch (e, st) {
      _log('download error: $e\n$st');
      return null;
    }
  }

  Future<Uint8List?> _loadThumb(String url0) async {
    final url = _hq(url0);
    if (_thumbCache.containsKey(url)) return _thumbCache[url];
    if (!_isHttpUrl(url)) {
      _thumbCache[url] = null;
      return null;
    }
    try {
      final res = await _fetch(url);
      if (!res.ok) {
        _thumbCache[url] = null;
        return null;
      }
      final mime = res.contentType ?? '';
      if (!mime.startsWith('image/')) {
        _thumbCache[url] = null;
        return null;
      }
      _thumbCache[url] = res.bytes;
      return res.bytes;
    } catch (_) {
      _thumbCache[url] = null;
      return null;
    }
  }

  // -------------------- utils --------------------

  Future<Directory> _ensureDownloadDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}VK Downloader');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      _log('downloadDir: created ${dir.path}');
    }
    return dir;
  }

  Future<File> _createUniqueFile(Directory dir, String base, String ext) async {
    final safeBase = base.isEmpty ? 'file' : base;
    var candidate = File('${dir.path}${Platform.pathSeparator}$safeBase.$ext');
    int counter = 1;
    while (await candidate.exists()) {
      candidate = File('${dir.path}${Platform.pathSeparator}$safeBase($counter).$ext');
      counter++;
    }
    return candidate;
  }

  String _basenameFromUrl(String url) {
    try {
      final p = Uri.parse(url).pathSegments;
      if (p.isEmpty) return 'file';
      final last = p.last;
      final dot = last.lastIndexOf('.');
      return dot > 0 ? last.substring(0, dot) : last;
    } catch (_) {
      return 'file';
    }
  }

  String _guessExtFromUrl(String url) {
    final lower = url.toLowerCase();
    for (final e in ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.mp4', '.m3u8', '.mov']) {
      if (lower.contains(e)) return e.replaceFirst('.', '');
    }
    return 'bin';
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').take(64);
  }

  void _trackUrl(String url) {
    if (url.isEmpty) return;
    setState(() {
      _visitedUrls.remove(url);
      _visitedUrls.add(url);
      if (_visitedUrls.length > 100) {
        _visitedUrls.removeRange(0, _visitedUrls.length - 100);
      }
    });
    _scheduleScrollToBottom(_visitedScrollController);
    unawaited(_persistVisitedUrls());
  }

  Future<void> _openUrl(String url0) async {
    final url = _isHttpUrl(url0) ? url0 : 'https://$url0';
    _urlCtrl.text = url;
    await _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  Future<void> _goBack(BuildContext context) async {
    final canGoBack = await _controller?.canGoBack() ?? false;
    if (canGoBack) {
      await _controller?.goBack();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No previous page')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) {
      return Scaffold(
        appBar: AppBar(title: const Text('VK Downloader')),
        body: const Center(child: Text('This application currently supports Windows and Linux.')),
      );
    }

    // фильтруем валидные ссылки, нормализуем и убираем дубликаты
    final mediaHq = _mediaUrlsRaw.map(_hq).where(_isRelevantMediaUrl).toSet().toList(growable: false);
    final searchLower = _mediaSearch.toLowerCase();
    final filteredMedia = mediaHq
        .where((url) => searchLower.isEmpty || url.toLowerCase().contains(searchLower))
        .toList(growable: false);
    final selectedCount = _selectedMedia.length;
    final userName = _userInfo['name'];
    final userId = _userInfo['id'];
    final userAvatar = _userInfo['avatar'];



    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _goBack(context),
        ),
        title: const Text('VK Downloader'),
        actions: [
          IconButton(
            tooltip: 'DevTools',
            icon: const Icon(Icons.bug_report),
            onPressed: () => _controller?.openDevTools(),
          ),
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller?.reload(),
          ),
          IconButton(
            tooltip: _isSidePanelVisible ? 'Collapse media panel' : 'Expand media panel',
            icon: Icon(_isSidePanelVisible ? Icons.close_fullscreen : Icons.open_in_full),
            onPressed: () => _setSidePanelVisible(!_isSidePanelVisible),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _urlCtrl,
                              onSubmitted: _openUrl,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.language),
                                hintText: 'Введите URL',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Tooltip(
                                message: 'Navigate back in the web view',
                                child: FilledButton.tonalIcon(
                                  onPressed: () => _goBack(context),
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('Back'),
                                ),
                              ),
                              Tooltip(
                                message: 'Open the typed address',
                                child: FilledButton.icon(
                                  onPressed: () => _openUrl(_urlCtrl.text),
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Go'),
                                ),
                              ),
                              Tooltip(
                                message: 'Extract media links from the current page',
                                child: FilledButton.tonalIcon(
                                  onPressed: _extractMediaFromPage,
                                  icon: const Icon(Icons.photo_library),
                                  label: const Text('Scan media'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(_initialUrl)),
                    initialSettings: _settings,
                    onWebViewCreated: (controller) async {
                      _controller = controller;
                      _log('onWebViewCreated');
                      controller.addJavaScriptHandler(
                        handlerName: 'mediaHandler',
                        callback: (args) {
                          if (args.isEmpty) return null;
                          final raw = (args[0] as List).map((e) => '$e').toList();
                          setState(() {
                            _mediaUrlsRaw
                              ..clear()
                              ..addAll(raw);
                            _thumbCache.clear();
                            _selectedMedia.clear();
                          });
                          _log('mediaHandler: raw=${raw.length}');
                          return null;
                        },
                      );
                    },
                    shouldOverrideUrlLoading: (controller, navAction) async {
                      final url = navAction.request.url?.toString();
                      if (url != null) {
                        _log('[shouldOverride] $url');
                        _trackUrl(url);
                        _urlCtrl.text = url;
                      }
                      return NavigationActionPolicy.ALLOW;
                    },
                    onLoadStart: (controller, url) {
                      final u = url?.toString();
                      if (u != null) {
                        _log('[loadStart] $u');
                        _trackUrl(u);
                        _urlCtrl.text = u;
                      }
                    },
                    onLoadStop: (controller, url) async {
                      final u = url?.toString();
                      if (u != null) {
                        _log('[loadStop] $u');
                        _urlCtrl.text = u;
                        if (u.contains('vk.com/feed') || u.contains('vk.com/id') || u.contains('vk.com/im')) {
                          await _saveCookiesForUrl(u);
                        } else {
                          try {
                            final hasLogout = await controller.evaluateJavascript(source: '''
                              (function(){
                                try {
                                  var el = document.querySelector('a[href*="/logout"]') || document.querySelector('[data-l="logout"]');
                                  return !!el;
                                } catch(e){ return false; }
                              })();
                            ''');
                            if (hasLogout == true) await _saveCookiesForUrl(u);
                          } catch (_) {}
                        }
                      }
                      unawaited(_tryUpdateUserInfo());
                    },
                    onUpdateVisitedHistory: (controller, url, _) {
                      final u = url?.toString();
                      if (u != null) {
                        _log('[history] $u');
                        _trackUrl(u);
                        _urlCtrl.text = u;
                      }
                    },
                    onReceivedError: (controller, request, error) {
                      _log('[error] type=${error.type} desc=${error.description} url=${request.url}');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Load error: ${error.description}')),
                      );
                    },
                    onReceivedHttpError: (controller, request, errorResponse) {
                      _log('[httpError] status=${errorResponse.statusCode} url=${request.url}');
                    },
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOutCubic,
            width: _isSidePanelVisible ? 420 : 64,
            child: _isSidePanelVisible
                ? _buildExpandedSidebar(
                    context,
                    filteredMedia,
                    mediaHq,
                    selectedCount,
                    userName,
                    userId,
                    userAvatar,
                  )
                : _buildCollapsedSidebar(context),
          ),
        ],
      ),

    );

  }

  Widget _buildExpandedSidebar(
    BuildContext context,
    List<String> filteredMedia,
    List<String> mediaHq,
    int selectedCount,
    String? userName,
    String? userId,
    String? userAvatar,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_userInfo.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            color: theme.colorScheme.surfaceVariant,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: (userAvatar != null && userAvatar.isNotEmpty)
                      ? NetworkImage(userAvatar)
                      : null,
                  child: (userAvatar == null || userAvatar.isEmpty)
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        userName ?? 'VK user',
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (userId != null)
                        Text('ID: $userId', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          color: theme.colorScheme.surfaceVariant,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Found media',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Chip(label: Text('${filteredMedia.length}')),
              IconButton(
                tooltip: 'Clear media list',
                icon: const Icon(Icons.delete_sweep),
                onPressed: _isBulkDownloading || mediaHq.isEmpty
                    ? null
                    : () => _clearFoundMedia(context),
              ),
              IconButton(
                tooltip: 'Collapse media panel',
                icon: const Icon(Icons.keyboard_double_arrow_right),
                onPressed: () => _setSidePanelVisible(false),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            controller: _mediaSearchCtrl,
            onChanged: _updateMediaSearch,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _mediaSearch.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _mediaSearchCtrl.clear();
                        _updateMediaSearch('');
                      },
                    ),
              hintText: 'Search media URLs',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isBulkDownloading)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: _bulkDownloadTotal > 0
                          ? _bulkDownloadProcessed / _bulkDownloadTotal
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Saved $_bulkDownloadSucceeded of $_bulkDownloadTotal files${_bulkCancelRequested ? ' — stopping…' : ''}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    child: FilledButton.icon(
                      onPressed: selectedCount > 0 && !_isBulkDownloading
                          ? () => _downloadSelectedMedia(context)
                          : null,
                      icon: _isBulkDownloading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_for_offline),
                      label: Text(
                        selectedCount > 0
                            ? 'Download selected ($selectedCount)'
                            : 'Download selected',
                      ),
                    ),
                  ),
                  if (_isBulkDownloading)
                    FilledButton.tonalIcon(
                      onPressed:
                          _bulkCancelRequested ? null : _requestStopBulkDownload,
                      style: FilledButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      icon: Icon(
                        _bulkCancelRequested
                            ? Icons.hourglass_top
                            : Icons.stop_circle_outlined,
                      ),
                      label: Text(
                        _bulkCancelRequested ? 'Stopping…' : 'Stop',
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: filteredMedia.isEmpty || _isBulkDownloading
                        ? null
                        : () => _selectAllMedia(filteredMedia),
                    icon: const Icon(Icons.select_all),
                    label: const Text('Select all'),
                  ),
                  TextButton.icon(
                    onPressed: _selectedMedia.isNotEmpty && !_isBulkDownloading
                        ? _clearAllSelections
                        : null,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear selection'),
                  ),
                  TextButton.icon(
                    onPressed: mediaHq.isEmpty || _isBulkDownloading
                        ? null
                        : () => _clearFoundMedia(context),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear media'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredMedia.isEmpty
              ? Center(
                  child: Text(
                    mediaHq.isEmpty
                        ? 'No media yet — press “Scan media”'
                        : 'No media match your filter',
                    textAlign: TextAlign.center,
                  ),
                )
              : Scrollbar(
                  controller: _mediaScrollController,
                  thumbVisibility: filteredMedia.length > 4,
                  child: ListView.separated(
                    controller: _mediaScrollController,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filteredMedia.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final url = filteredMedia[i];
                      final isStream = _isStreamUrl(url);
                      final isVideo = _isVideoFile(url);
                      final isChecked = _selectedMedia.contains(url);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        leading: SizedBox(
                          width: 64,
                          height: 64,
                          child: isStream || isVideo
                              ? Icon(isStream ? Icons.live_tv : Icons.videocam, size: 32)
                              : FutureBuilder<Uint8List?>(
                                  future: _loadThumb(url),
                                  builder: (context, snap) {
                                    if (snap.connectionState == ConnectionState.waiting) {
                                      return const Center(
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      );
                                    }
                                    if (snap.data == null) {
                                      return const Icon(Icons.image_not_supported);
                                    }
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(snap.data!, fit: BoxFit.cover),
                                    );
                                  },
                                ),
                        ),
                        title: Text(
                          url,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: isStream
                            ? const Text('HLS stream (.m3u8) — use an HLS downloader')
                            : null,
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            Tooltip(
                              message: isStream
                                  ? 'Streams cannot be selected'
                                  : (isChecked ? 'Remove from selection' : 'Add to selection'),
                              child: Checkbox(
                                value: isChecked,
                                onChanged: isStream
                                    ? null
                                    : (value) => _toggleMediaSelection(url, value ?? false),
                              ),
                            ),
                            Tooltip(
                              message: 'Download file',
                              child: IconButton(
                                icon: const Icon(Icons.download),
                                onPressed: isStream
                                    ? null
                                    : () async {
                                        final path = await _downloadToDisk(url);
                                        if (!mounted) return;
                                        if (path != null) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Saved: $path')),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Save failed')),
                                          );
                                        }
                                      },
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _openUrl(url),
                        onLongPress: isStream ? null : () => _toggleMediaSelection(url, !isChecked),
                      );
                    },
                  ),
                ),
        ),
        const Divider(height: 1),
        Container(
          padding: const EdgeInsets.all(12),
          color: theme.colorScheme.surfaceVariant,
          child: Text('Visited pages', style: theme.textTheme.titleMedium),
        ),
        SizedBox(
          height: 110,
          child: Scrollbar(
            controller: _visitedScrollController,
            thumbVisibility: _visitedUrls.length > 4,
            child: ListView.builder(
              controller: _visitedScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _visitedUrls.length,
              itemBuilder: (_, i) {
                final url = _visitedUrls[i];
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: const Icon(Icons.history, size: 18),
                  title: Text(
                    url,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _openUrl(url),
                );
              },
            ),
          ),
        ),
        const Divider(height: 1),
        Container(
          padding: const EdgeInsets.all(12),
          color: theme.colorScheme.surfaceVariant,
          child: Text('Events log', style: theme.textTheme.titleMedium),
        ),
        SizedBox(
          height: 110,
          child: Scrollbar(
            controller: _eventsScrollController,
            thumbVisibility: _events.length > 4,
            child: ListView.builder(
              controller: _eventsScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: _events.length,
              itemBuilder: (_, i) => Text(
                _events[i],
                style: theme.textTheme.bodySmall?.copyWith(height: 1.2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsedSidebar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceVariant,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Expand media panel',
              icon: const Icon(Icons.keyboard_double_arrow_left),
              onPressed: () => _setSidePanelVisible(true),
            ),
            const SizedBox(height: 12),
            RotatedBox(
              quarterTurns: 3,
              child: Text(
                'MEDIA PANEL',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- helpers ----

class _DownloadResult {
  final bool ok;
  final int status;
  final String? contentType;
  final Uint8List? bytes;
  _DownloadResult({required this.ok, required this.status, this.contentType, this.bytes});
}

extension _Take on String {
  String take(int n) => length <= n ? this : substring(0, n);
}
