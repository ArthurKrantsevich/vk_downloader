import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/media_url_normalizer.dart';

class MediaDownloadResult {
  const MediaDownloadResult({
    required this.ok,
    required this.statusCode,
    required this.contentType,
    required this.bytes,
  });

  final bool ok;
  final int statusCode;
  final String? contentType;
  final Uint8List? bytes;
}

class MediaDownloadService {
  MediaDownloadService(this._normalizer);

  final MediaUrlNormalizer _normalizer;

  static const _uaWebLike =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0';

  Map<String, String> buildHeaders(String referer) {
    return {
      HttpHeaders.userAgentHeader: _uaWebLike,
      HttpHeaders.refererHeader: referer,
      HttpHeaders.acceptHeader:
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    };
  }

  Future<MediaDownloadResult> fetch(String url, String referer) async {
    final uri = Uri.parse(url);
    final client = HttpClient()..userAgent = _uaWebLike;
    try {
      final request = await client.getUrl(uri);
      final headers = buildHeaders(referer);
      headers.forEach(request.headers.set);
      final response = await request.close();
      final mime = response.headers.contentType?.mimeType;
      final bytes = await consolidateHttpClientResponseBytes(response);
      return MediaDownloadResult(
        ok: response.statusCode == 200,
        statusCode: response.statusCode,
        contentType: mime,
        bytes: bytes,
      );
    } finally {
      client.close();
    }
  }

  Future<String?> downloadToDisk(String url, String referer) async {
    final normalized = _normalizer.normalize(url);
    try {
      final result = await fetch(normalized, referer);
      if (!result.ok || result.bytes == null) {
        return null;
      }
      final mime = result.contentType ?? '';
      final isStream =
          mime.contains('m3u8') || normalized.toLowerCase().endsWith('.m3u8');
      if (isStream) {
        return null;
      }
      final ext = _extFromMime(mime, fallback: _guessExtFromUrl(normalized));
      final dir = await _ensureDownloadDirectory();
      final base = _sanitizeFileName(_basenameFromUrl(normalized));
      final file = await _createUniqueFile(dir, base, ext);
      await file.writeAsBytes(result.bytes!, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> loadThumbnail(String url, String referer) async {
    final normalized = _normalizer.normalize(url);
    try {
      final result = await fetch(normalized, referer);
      if (!result.ok || result.bytes == null) {
        return null;
      }
      final mime = result.contentType ?? '';
      if (!mime.startsWith('image/')) {
        return null;
      }
      return result.bytes;
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _ensureDownloadDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}VK Downloader');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _createUniqueFile(Directory dir, String base, String ext) async {
    final safeBase = base.isEmpty ? 'file' : base;
    var candidate = File('${dir.path}${Platform.pathSeparator}$safeBase.$ext');
    var counter = 1;
    while (await candidate.exists()) {
      candidate =
          File('${dir.path}${Platform.pathSeparator}$safeBase($counter).$ext');
      counter++;
    }
    return candidate;
  }

  String _basenameFromUrl(String url) {
    try {
      final segments = Uri.parse(url).pathSegments;
      if (segments.isEmpty) return 'file';
      final last = segments.last;
      final dot = last.lastIndexOf('.');
      return dot > 0 ? last.substring(0, dot) : last;
    } catch (_) {
      return 'file';
    }
  }

  String _guessExtFromUrl(String url) {
    final lower = url.toLowerCase();
    for (final ext in const ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.mp4', '.m3u8', '.mov']) {
      if (lower.contains(ext)) {
        return ext.replaceFirst('.', '');
      }
    }
    return 'bin';
  }

  String _extFromMime(String mime, {String fallback = 'bin'}) {
    final lower = mime.toLowerCase();
    if (lower.contains('jpeg')) return 'jpg';
    if (lower.contains('png')) return 'png';
    if (lower.contains('gif')) return 'gif';
    if (lower.contains('webp')) return 'webp';
    if (lower.contains('bmp')) return 'bmp';
    if (lower.contains('svg')) return 'svg';
    if (lower.contains('mp4')) return 'mp4';
    if (lower.contains('mpeg')) return 'mpg';
    if (lower.contains('quicktime')) return 'mov';
    if (lower.contains('x-mpegurl') ||
        lower.contains('vnd.apple.mpegurl') ||
        lower.contains('hls') ||
        lower.contains('m3u8')) {
      return 'm3u8';
    }
    return fallback;
  }

  String _sanitizeFileName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return sanitized.length <= 64 ? sanitized : sanitized.substring(0, 64);
  }
}
