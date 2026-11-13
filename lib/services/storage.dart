import 'dart:convert';
import '../game/data.dart';
import 'storage_backend.dart';
export 'storage_backend.dart';
export 'storage_io.dart' if (dart.library.html) 'storage_web.dart'
    show createBackend;

const manualSlots = ['0', '1', '2'];
const autoSlot = 'auto';
const defaultMeta = {'volume': 0.9, 'muted': false, 'seenHelp': false};

class SaveStore {
  SaveStore(this.backend, {DateTime Function()? now})
      : now = now ?? DateTime.now;
  final StorageBackend backend;
  final DateTime Function() now;
  final _raw = <String, String>{};
  Future<void> _pending = Future.value();
  Future<void> init() async {
    for (final key in [
      'meta',
      ...[...manualSlots, autoSlot].map((s) => 'slot-$s')
    ]) {
      final value = await backend.read('star-v1:$key');
      if (value != null) _raw[key] = value;
    }
  }

  Obj loadMeta() {
    try {
      final o = _raw['meta'] != null ? jsonDecode(_raw['meta']!) : {};
      return {
        'volume': o['volume'] is num ? o['volume'] : 0.9,
        'muted': jsTruthy(o['muted']),
        'seenHelp': jsTruthy(o['seenHelp'])
      };
    } catch (_) {
      return Map.of(defaultMeta);
    }
  }

  Future<bool> _set(String key, String value) {
    // Snapshot first; serialize writes so a slower earlier save cannot overwrite a later one.
    final operation = _pending.then((_) async {
      final ok = await backend.write('star-v1:$key', value);
      if (ok) _raw[key] = value;
      return ok;
    });
    _pending = operation.then((_) {});
    return operation;
  }

  Future<bool> saveMeta(Obj meta) => _set('meta', jsonEncode(meta));
  Future<bool> writeSlot(String name, Obj state) {
    if (![...manualSlots, autoSlot].contains(name)) return Future.value(false);
    try {
      final body = jsonDecode(jsonEncode(state)) as Obj;
      body['history'] = <dynamic>[];
      return _set(
          'slot-$name',
          jsonEncode({
            'savedAt': now().millisecondsSinceEpoch,
            'floor': state['floor'],
            'state': body
          }));
    } catch (_) {
      return Future.value(false);
    }
  }

  Obj? readSlot(String name) {
    try {
      final raw = _raw['slot-$name'];
      if (raw == null) return null;
      final entry = jsonDecode(raw);
      return entry is Obj && jsTruthy(entry['state']) ? entry : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteSlot(String name) {
    if (![...manualSlots, autoSlot].contains(name)) return Future.value();
    _pending = _pending.then((_) async {
      await backend.remove('star-v1:slot-$name');
      final raw = await backend.read('star-v1:slot-$name');
      if (raw == null) {
        _raw.remove('slot-$name');
      } else {
        _raw['slot-$name'] = raw;
      }
    });
    return _pending;
  }

  List<Obj> listSlots() => [...manualSlots, autoSlot]
      .map((s) => <String, dynamic>{'name': s, 'entry': readSlot(s)})
      .toList();
  Future<void> get settled => _pending;
}
