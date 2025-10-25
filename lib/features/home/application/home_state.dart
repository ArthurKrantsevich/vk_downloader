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
  });

  factory HomeState.initial() {
    const initialUrl = 'https://google.com';
    return const HomeState(
      currentUrl: initialUrl,
      visitedUrls: [initialUrl],
      events: [],
      mediaItems: [],
      selectedMedia: <String>{},
      userInfo: <String, String>{},
      isSidePanelVisible: true,
      mediaSearch: '',
      isBulkDownloading: false,
      bulkDownloadTotal: 0,
      bulkDownloadProcessed: 0,
      bulkDownloadSucceeded: 0,
      isBulkCancelRequested: false,
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
    );
  }
}
