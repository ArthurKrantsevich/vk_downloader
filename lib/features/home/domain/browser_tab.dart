/// Represents a single browser tab with its state
class BrowserTab {
  const BrowserTab({
    required this.id,
    required this.url,
    required this.title,
    this.favicon,
  });

  /// Unique identifier for this tab
  final String id;

  /// Current URL of the tab
  final String url;

  /// Page title (or URL if title not available)
  final String title;

  /// Optional favicon URL
  final String? favicon;

  BrowserTab copyWith({
    String? id,
    String? url,
    String? title,
    String? favicon,
  }) {
    return BrowserTab(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      favicon: favicon ?? this.favicon,
    );
  }

  /// Create a tab with a unique ID based on timestamp
  factory BrowserTab.create({
    required String url,
    String? title,
    String? favicon,
  }) {
    final id = 'tab_${DateTime.now().millisecondsSinceEpoch}';
    return BrowserTab(
      id: id,
      url: url,
      title: title ?? _getTitleFromUrl(url),
      favicon: favicon,
    );
  }

  static String _getTitleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return 'New Tab';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrowserTab &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
