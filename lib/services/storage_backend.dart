abstract class StorageBackend {
  Future<String?> read(String key);
  Future<bool> write(String key, String value);
  Future<void> remove(String key);
}

class MemoryBackend implements StorageBackend {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<bool> write(String key, String value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}
