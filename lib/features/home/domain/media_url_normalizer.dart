class MediaUrlNormalizer {
  const MediaUrlNormalizer();

  bool isHttpUrl(String url) =>
      url.startsWith('http://') || url.startsWith('https://');

  String normalizeVkImage(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      if (!(host.contains('userapi.com') || host.contains('vkuserphotos'))) {
        return url;
      }
      final params = Map<String, List<String>>.from(uri.queryParametersAll);
      final availableSizes = params['as']?.isNotEmpty == true
          ? params['as']!.first.split(',')
          : <String>[];
      var maxWidth = 0;
      for (final size in availableSizes) {
        final width = int.tryParse(size.split('x').first) ?? 0;
        if (width > maxWidth) {
          maxWidth = width;
        }
      }
      maxWidth = maxWidth > 0 ? maxWidth : 1280;
      params['cs'] = ['${maxWidth}x0'];
      params.remove('u');
      final flat = <String, String>{};
      for (final entry in params.entries) {
        if (entry.value.isEmpty) continue;
        flat[entry.key] = entry.value.first;
      }
      final rebuilt = uri.replace(queryParameters: flat);
      return rebuilt.toString();
    } catch (_) {
      return url;
    }
  }

  String normalize(String url) => normalizeVkImage(url);
}
