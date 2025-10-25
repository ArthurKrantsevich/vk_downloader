class MediaFilter {
  const MediaFilter();

  /// Determines whether the given URL is relevant (points to a media resource).
  bool isRelevant(String url) {
    final lower = url.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return false;
    }

    // Blocked substrings
    const blockedFragments = [
      'data:image',
      'blank.html',
      'favicon',
      'adsstatic',
      'analytics',
      'doubleclick',
      'metrics.',
      'pixel.',
    ];
    if (blockedFragments.any(lower.contains)) {
      return false;
    }

    // Allowed file extensions
    const allowedExts = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.bmp',
      '.svg',
      '.mp4',
      '.mov',
      '.m4v',
      '.avi',
      '.mkv',
      '.webm',
      '.m3u8',
      '.mp3',
      '.ogg',
      '.wav',
    ];
    final hasExt = allowedExts.any(lower.contains);

    // Parse URL host
    final uri = Uri.tryParse(url);
    final host = uri?.host.toLowerCase() ?? '';

    // Known media-hosting domains (VK + general platforms)
    const mediaHosts = [
      // VK ecosystem
      'vk.com',
      'userapi.com',
      'vkuserphotos',
      'vkvideo',
      'vkuservideo',
      'vkuserlive',
      'vkuseraudio',
      // YouTube
      'youtube.com',
      'youtu.be',
      'ytimg.com',
      // Instagram
      'instagram.com',
      'cdninstagram.com',
      'fbcdn.net',
      // TikTok
      'tiktok.com',
      'ttwstatic.com',
      // Telegram
      't.me',
      'telegram.org',
      'cdn4.telegram-cdn.org',
      // Twitter / X
      'twitter.com',
      'twimg.com',
      'x.com',
      // Reddit
      'reddit.com',
      'redd.it',
      'preview.redd.it',
      'external-preview.redd.it',
      // Others
      'imgur.com',
      'giphy.com',
      'tenor.com',
      'cdn.discordapp.com',
      'media.discordapp.net',
    ];

    final matchesHost = mediaHosts.any(host.contains);

    // VK / social specific fallback logic
    if (matchesHost && (hasExt || _isSocialMediaResource(lower))) {
      return true;
    }

    // Generic image/video links
    return hasExt;
  }

  /// Detects known non-extension media URLs (video endpoints, etc.)
  bool _isSocialMediaResource(String lower) {
    return lower.contains('video_files') ||
        lower.contains('photo.php') ||
        lower.contains('photo-') ||
        lower.contains('stories') ||
        lower.contains('reel') ||
        lower.contains('shorts') ||
        lower.contains('status/') ||
        lower.contains('media/') ||
        lower.contains('attachments');
  }
}
