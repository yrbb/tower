import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:star_tower/game/data.dart';
import 'package:star_tower/game/engine.dart';
import 'package:star_tower/services/hold_repeat.dart';
import 'package:star_tower/services/storage.dart';
import 'package:star_tower/services/storage_io.dart';

void main() {
  final data =
      GameData.fromJson(File('assets/data/game.json').readAsStringSync());
  testWidgets('Hold delay matches 0, 370, 510 ms and stops after failed step',
      (tester) async {
    var steps = 0;
    final hold = HoldRepeat(() => ++steps < 3);
    hold.start();
    expect(steps, 1);
    await tester.pump(const Duration(milliseconds: 230));
    expect(steps, 1);
    await tester.pump(const Duration(milliseconds: 139));
    expect(steps, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(steps, 2);
    await tester.pump(const Duration(milliseconds: 140));
    expect(steps, 3);
    expect(hold.active, false);
    await tester.pump(const Duration(seconds: 1));
    expect(steps, 3);
    hold.stop();
  });
  test(
      'Save captures action-time state, omits history, survives new store and deletes',
      () async {
    final dir = await Directory.systemTemp.createTemp('star-save-test-');
    try {
      final store = SaveStore(FileBackend(dir.path),
          now: () => DateTime.fromMillisecondsSinceEpoch(1234));
      await store.init();
      final state = Engine(data).createGame();
      state['history'].add('{}');
      final first = store.writeSlot('0', state);
      state['hero']['hp'] = 99;
      final second = store.writeSlot('1', state);
      expect(await first, true);
      expect(await second, true);
      expect(store.readSlot('0')!['state']['hero']['hp'], 1000);
      expect(store.readSlot('0')!['state']['history'], isEmpty);
      expect(store.readSlot('0')!['savedAt'], 1234);
      final reloaded = SaveStore(FileBackend(dir.path));
      await reloaded.init();
      expect(reloaded.readSlot('1')!['state']['hero']['hp'], 99);
      await reloaded.deleteSlot('0');
      expect(reloaded.readSlot('0'), null);
      expect(await reloaded.writeSlot('../escape', state), false);
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test('Storage preserves original JavaScript JSON truthiness', () async {
    for (final value in [
      null,
      false,
      0,
      '',
      true,
      1,
      'false',
      <dynamic>[],
      <String, dynamic>{}
    ]) {
      final backend = MemoryBackend();
      backend.values['star-v1:meta'] =
          jsonEncode({'muted': value, 'seenHelp': value});
      backend.values['star-v1:slot-0'] = jsonEncode({'state': value});
      final storage = SaveStore(backend);
      await storage.init();
      final truthy =
          value != null && value != false && value != 0 && value != '';
      expect(storage.loadMeta()['muted'], truthy);
      expect(storage.loadMeta()['seenHelp'], truthy);
      expect(storage.readSlot('0') != null, truthy);
    }
  });
  test('Malformed JSON and failed write preserve original slot', () async {
    final backend = _FailingBackend();
    final storage = SaveStore(backend);
    await storage.init();
    expect(await storage.writeSlot('0', Engine(data).createGame()), true);
    backend.fail = true;
    final state = Engine(data).createGame();
    state['hero']['hp'] = 2;
    expect(await storage.writeSlot('0', state), false);
    expect(storage.readSlot('0')!['state']['hero']['hp'], 1000);
    backend.values['star-v1:slot-1'] = '{bad';
    backend.values['star-v1:meta'] = 'null';
    final reload = SaveStore(backend);
    await reload.init();
    expect(reload.readSlot('1'), null);
    expect(reload.loadMeta(), defaultMeta);
    expect(jsonDecode(backend.values['star-v1:slot-0']!)['state']['history'],
        isEmpty);
  });
}

class _FailingBackend extends MemoryBackend {
  bool fail = false;
  @override
  Future<bool> write(String key, String value) async =>
      fail ? false : super.write(key, value);
}
