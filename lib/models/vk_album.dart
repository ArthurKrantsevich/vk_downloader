class VkAlbum {
  const VkAlbum({
    required this.id,
    required this.title,
    required this.photoCount,
    this.coverUrl,
  });

  final String id;
  final String title;
  final int photoCount;
  final String? coverUrl;

  factory VkAlbum.fromJson(Map<String, dynamic> json) {
    return VkAlbum(
      id: json['id'] as String,
      title: json['title'] as String,
      photoCount: json['photoCount'] as int,
      coverUrl: json['coverUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'photoCount': photoCount,
      'coverUrl': coverUrl,
    };
  }
}
