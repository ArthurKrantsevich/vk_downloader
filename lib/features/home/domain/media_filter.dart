class MediaFilter {
  const MediaFilter();

  bool isRelevant(String url) {
    final lower = url.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return false;
    }
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
        (lower.contains('video_files') ||
            lower.contains('photo.php') ||
            lower.contains('photo-'))) {
      return true;
    }
    return hasExt;
  }
}
