import 'dart:typed_data';

class MediaItem {
  MediaItem({
    required this.originalUrl,
    required this.normalizedUrl,
    this.thumbnail,
  });

  final String originalUrl;
  final String normalizedUrl;
  final Uint8List? thumbnail;

  bool get isStream => normalizedUrl.toLowerCase().endsWith('.m3u8');

  bool get isVideo =>
      RegExp(r'\.(mp4|mov|m4v|webm)(\?|$)', caseSensitive: false)
          .hasMatch(normalizedUrl);

  MediaItem copyWith({
    String? originalUrl,
    String? normalizedUrl,
    Uint8List? thumbnail,
    bool clearThumbnail = false,
  }) {
    return MediaItem(
      originalUrl: originalUrl ?? this.originalUrl,
      normalizedUrl: normalizedUrl ?? this.normalizedUrl,
      thumbnail: clearThumbnail ? null : thumbnail ?? this.thumbnail,
    );
  }
}
