// Browser preview uses the same localStorage keys as the reference.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'storage_backend.dart';

Future<StorageBackend> createBackend() async => BrowserBackend();

class BrowserBackend implements StorageBackend {
  @override
  Future<String?> read(String key) async {
    try {
      return html.window.localStorage[key];
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> write(String key, String value) async {
    try {
      html.window.localStorage[key] = value;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> remove(String key) async {
    try {
      html.window.localStorage.remove(key);
    } catch (_) {}
  }
}
