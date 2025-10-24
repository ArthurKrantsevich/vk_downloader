class VkPhoto {
  const VkPhoto({
    required this.id,
    required this.albumId,
    required this.url,
    this.caption,
  });

  final String id;
  final String albumId;
  final String url;
  final String? caption;

  factory VkPhoto.fromJson(Map<String, dynamic> json) {
    return VkPhoto(
      id: json['id'] as String,
      albumId: json['albumId'] as String,
      url: json['url'] as String,
      caption: json['caption'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'albumId': albumId,
      'url': url,
      'caption': caption,
    };
  }
}
