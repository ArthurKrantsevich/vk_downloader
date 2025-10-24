import '../models/download_task.dart';
import '../models/vk_photo.dart';

abstract class IDownloadService {
  Stream<DownloadTask> downloadPhotos(List<VkPhoto> photos);
}

class DownloadService implements IDownloadService {
  @override
  Stream<DownloadTask> downloadPhotos(List<VkPhoto> photos) async* {
    // TODO: Implement background download logic with progress tracking.
    yield const DownloadTask(
      id: 'placeholder',
      status: DownloadStatus.pending,
      progress: 0,
    );
  }
}
