import '../models/vk_album.dart';
import '../models/vk_photo.dart';

abstract class IVkApiService {
  Future<List<VkAlbum>> fetchAlbums();
  Future<List<VkPhoto>> fetchPhotos(String albumId);
}

class VkApiService implements IVkApiService {
  @override
  Future<List<VkAlbum>> fetchAlbums() async {
    // TODO: Call VK API to retrieve albums for the authenticated user.
    return const [];
  }

  @override
  Future<List<VkPhoto>> fetchPhotos(String albumId) async {
    // TODO: Call VK API to retrieve photos for the specified album.
    return const [];
  }
}
