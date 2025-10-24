import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
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
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _transitionDelay = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(_transitionDelay, _goToHome);
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_download,
              size: 96,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'VK Downloader',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const CircularProgressIndicator(),
          ],
        ),
      ),
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

  final List<String> _visitedUrls = <String>[_initialUrl];
  late final WebViewController _controller;

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows);

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            _trackUrl(request.url);
            return NavigationDecision.navigate;
          },
          onPageStarted: _trackUrl,
        ),
      )
      ..loadRequest(Uri.parse(_initialUrl));
  }

  void _trackUrl(String url) {
    if (url.isEmpty) return;
    if (_visitedUrls.contains(url)) return;
    setState(() {
      _visitedUrls.insert(0, url);
    });
  }

  void _openUrl(String url) {
    _controller.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) {
      return Scaffold(
        appBar: AppBar(title: const Text('VK Downloader')),
        body: const Center(
          child: Text('This application currently supports Windows and Linux.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('VK Downloader')),
      body: Row(
        children: [
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: Text(
                    'Visited Links',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _visitedUrls.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final url = _visitedUrls[index];
                      return ListTile(
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
