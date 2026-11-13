import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'storage_backend.dart';

Future<StorageBackend> createBackend() async =>
    FileBackend((await getApplicationSupportDirectory()).path);

class FileBackend implements StorageBackend {
  FileBackend(this.path);
  final String path;
  File file(String key) => File('$path/$key.json');
  @override
  Future<String?> read(String key) async {
    try {
      return await file(key).readAsString();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> write(String key, String value) async {
    try {
      await Directory(path).create(recursive: true);
      final temp = File('$path/$key.tmp');
      await temp.writeAsString(value, flush: true);
      await temp.rename(file(key).path);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> remove(String key) async {
    try {
      await file(key).delete();
    } catch (_) {/* Same silent deletion failure as upstream. */}
  }
}
