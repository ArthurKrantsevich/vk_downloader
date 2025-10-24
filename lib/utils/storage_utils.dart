import 'dart:io';

class StorageUtils {
  const StorageUtils._();

  static Future<Directory> ensureDirectory(String path) async {
    final directory = Directory(path);
    if (await directory.exists()) {
      return directory;
    }
    return directory.create(recursive: true);
  }
}
