import '../domain/browser_tab.dart';
import '../domain/media_item.dart';

class HomeState {
  const HomeState({
    required this.currentUrl,
    required this.visitedUrls,
    required this.events,
    required this.mediaItems,
    required this.selectedMedia,
    required this.userInfo,
    required this.isSidePanelVisible,
    required this.mediaSearch,
    required this.isBulkDownloading,
    required this.bulkDownloadTotal,
    required this.bulkDownloadProcessed,
    required this.bulkDownloadSucceeded,
    required this.isBulkCancelRequested,
    required this.tabs,
    required this.activeTabId,
  });

  factory HomeState.initial() {
    const initialUrl = 'https://google.com';
    final initialTab = BrowserTab.create(url: initialUrl, title: 'Google');
    return HomeState(
      currentUrl: initialUrl,
      visitedUrls: const [initialUrl],
      events: const [],
      mediaItems: const [],
      selectedMedia: const <String>{},
      userInfo: const <String, String>{},
      isSidePanelVisible: true,
      mediaSearch: '',
      isBulkDownloading: false,
      bulkDownloadTotal: 0,
      bulkDownloadProcessed: 0,
      bulkDownloadSucceeded: 0,
      isBulkCancelRequested: false,
      tabs: [initialTab],
      activeTabId: initialTab.id,
    );
  }

  final String currentUrl;
  final List<String> visitedUrls;
  final List<String> events;
  final List<MediaItem> mediaItems;
  final Set<String> selectedMedia;
  final Map<String, String> userInfo;
  final bool isSidePanelVisible;
  final String mediaSearch;
  final bool isBulkDownloading;
  final int bulkDownloadTotal;
  final int bulkDownloadProcessed;
  final int bulkDownloadSucceeded;
  final bool isBulkCancelRequested;
  final List<BrowserTab> tabs;
  final String activeTabId;

  HomeState copyWith({
    String? currentUrl,
    List<String>? visitedUrls,
    List<String>? events,
    List<MediaItem>? mediaItems,
    Set<String>? selectedMedia,
    Map<String, String>? userInfo,
    bool? isSidePanelVisible,
    String? mediaSearch,
    bool? isBulkDownloading,
    int? bulkDownloadTotal,
    int? bulkDownloadProcessed,
    int? bulkDownloadSucceeded,
    bool? isBulkCancelRequested,
    List<BrowserTab>? tabs,
    String? activeTabId,
  }) {
    return HomeState(
      currentUrl: currentUrl ?? this.currentUrl,
      visitedUrls: visitedUrls ?? this.visitedUrls,
      events: events ?? this.events,
      mediaItems: mediaItems ?? this.mediaItems,
      selectedMedia: selectedMedia ?? this.selectedMedia,
      userInfo: userInfo ?? this.userInfo,
      isSidePanelVisible: isSidePanelVisible ?? this.isSidePanelVisible,
      mediaSearch: mediaSearch ?? this.mediaSearch,
      isBulkDownloading: isBulkDownloading ?? this.isBulkDownloading,
      bulkDownloadTotal: bulkDownloadTotal ?? this.bulkDownloadTotal,
      bulkDownloadProcessed:
          bulkDownloadProcessed ?? this.bulkDownloadProcessed,
      bulkDownloadSucceeded:
          bulkDownloadSucceeded ?? this.bulkDownloadSucceeded,
      isBulkCancelRequested:
          isBulkCancelRequested ?? this.isBulkCancelRequested,
      tabs: tabs ?? this.tabs,
      activeTabId: activeTabId ?? this.activeTabId,
    );
  }

  /// Get the currently active tab
  BrowserTab? get activeTab {
    try {
      return tabs.firstWhere((tab) => tab.id == activeTabId);
    } catch (_) {
      return tabs.isNotEmpty ? tabs.first : null;
    }
  }

  /// Check if we can add more tabs (max 5)
  bool get canAddTab => tabs.length < 5;
}
