// lib/main.dart
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
  final List<String> _visitedUrls = <String>[_initialUrl];
  final List<String> _events = <String>[];
  final List<String> _mediaUrlsRaw = <String>[];   // как пришло из страницы
  final Map<String, Uint8List?> _thumbCache = {};  // кэш превью

  InAppWebViewController? _controller;
  InAppWebViewSettings _settings = InAppWebViewSettings(
    javaScriptEnabled: true,
    allowsInlineMediaPlayback: true,
    mediaPlaybackRequiresUserGesture: false,
    isInspectable: true,
  );

  bool get _isDesktop =>
      !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux);

  void _log(String s) {
    setState(() => _events.insert(0, s));
    // ignore: avoid_print
    print(s);
  }

  @override
  void initState() {
    super.initState();
    _restoreCookiesOnStart();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
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
      final asList = (qpAll['as']?.isNotEmpty ?? false) ? qpAll['as']!.first.split(',') : <String>[];
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
      final dir = await getApplicationDocumentsDirectory();
      final base = _sanitizeFileName(_basenameFromUrl(url));
      final file = File('${dir.path}/$base.$ext');
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
    if (!_visitedUrls.contains(url)) {
      setState(() => _visitedUrls.insert(0, url));
    }
  }

  Future<void> _openUrl(String url0) async {
    final url = _isHttpUrl(url0) ? url0 : 'https://$url0';
    _urlCtrl.text = url;
    await _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
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
    final mediaHq = _mediaUrlsRaw
        .where(_isHttpUrl)
        .map(_hq)
        .toSet()
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
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
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: Row(
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
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _openUrl(_urlCtrl.text),
                        child: const Text('Go'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: _extractMediaFromPage,
                        child: const Text('Scan media'),
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
          SizedBox(
            width: 430,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: Text('Found media (HQ)', style: Theme.of(context).textTheme.titleMedium),
                ),
                Expanded(
                  child: mediaHq.isEmpty
                      ? const Center(child: Text('Нет медиа — нажмите "Scan media"'))
                      : ListView.separated(
                    itemCount: mediaHq.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final url = mediaHq[i];
                      final isM3U8 = url.toLowerCase().endsWith('.m3u8');
                      final isVidByExt = RegExp(r'\.(mp4|mov|m4v|webm)(\?|$)', caseSensitive: false).hasMatch(url);
                      final isMaybeVideo = isM3U8 || isVidByExt;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        leading: SizedBox(
                          width: 64,
                          height: 64,
                          child: isMaybeVideo
                              ? const Icon(Icons.videocam, size: 32)
                              : FutureBuilder<Uint8List?>(
                            future: _loadThumb(url),
                            builder: (context, snap) {
                              if (snap.connectionState == ConnectionState.waiting) {
                                return const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)));
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
                        title: Text(url, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: isM3U8
                            ? const Text('HLS stream (.m3u8) — нужен загрузчик HLS')
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: isM3U8
                              ? null
                              : () async {
                            final path = await _downloadToDisk(url);
                            if (path != null) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved: $path')));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save failed')));
                            }
                          },
                        ),
                        onTap: () => _openUrl(url),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: Text('Visited Links', style: Theme.of(context).textTheme.titleMedium),
                ),
                SizedBox(
                  height: 140,
                  child: ListView.separated(
                    itemCount: _visitedUrls.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final url = _visitedUrls[i];
                      return ListTile(
                        dense: true,
                        title: Text(url, maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => _openUrl(url),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: Text('Events', style: Theme.of(context).textTheme.titleMedium),
                ),
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    reverse: true,
                    itemCount: _events.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text(_events[i], style: const TextStyle(fontSize: 12, height: 1.2)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
