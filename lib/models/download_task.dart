enum DownloadStatus { pending, inProgress, completed, failed }

class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.status,
    required this.progress,
    this.error,
  });

  final String id;
  final DownloadStatus status;
  final int progress; // Value between 0 and 100.
  final String? error;

  DownloadTask copyWith({
    DownloadStatus? status,
    int? progress,
    String? error,
  }) {
    return DownloadTask(
      id: id,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
    );
  }
}
