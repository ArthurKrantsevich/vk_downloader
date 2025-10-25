import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class PreferencesStore {
  PreferencesStore(this.fileName);

  final String fileName;

  File? _file;

  Future<File> _ensureFile() async {
    if (_file != null) {
      return _file!;
    }
    final docs = await getApplicationDocumentsDirectory();
    final file = File('${docs.path}${Platform.pathSeparator}$fileName');
    if (!await file.exists()) {
      await file.create(recursive: true);
      await file.writeAsString('{}');
    }
    _file = file;
    return file;
  }

  Future<Map<String, dynamic>> read() async {
    try {
      final file = await _ensureFile();
      final text = await file.readAsString();
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> write(Map<String, dynamic> data) async {
    try {
      final file = await _ensureFile();
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {
      // Ignore write errors: preferences are non-critical
    }
  }
}
