import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:star_tower/game/data.dart';
import 'package:star_tower/game_controller.dart';
import 'package:star_tower/services/audio.dart';
import 'package:star_tower/services/storage.dart';
import 'parity_test.dart' show canonical;

void main() {
  testWidgets(
      'Application controller matches source actions, UI state and storage',
      (tester) async {
    final data =
        GameData.fromJson(File('assets/data/game.json').readAsStringSync());
    final storage = SaveStore(MemoryBackend(),
        now: () => DateTime.fromMillisecondsSinceEpoch(1700000000000));
    await storage.init();
    final c = GameController(data, storage, SilentAudio());
    final List fixtures =
        jsonDecode(File('test/fixtures/controller.json').readAsStringSync());
    for (var i = 0; i < fixtures.length; i++) {
      final f = fixtures[i];
      final List a = f['args'];
      switch (f['name']) {
        case 'newGame':
          c.newGame();
        case 'closeModal':
          c.closeModal();
        case 'openModal':
          c.openModal(a[0]);
        case 'move':
          c.move(a[0]);
        case 'undo':
          c.undo();
        case 'saveSlot':
          await c.saveSlot(a[0]);
        case 'loadSlot':
          c.loadSlot(a[0]);
        case 'deleteSlot':
          await c.deleteSlot(a[0]);
        case 'continueAuto':
          c.loadSlot(autoSlot);
        case 'setVolume':
          c.setVolume((a[0] as num).toDouble());
        case 'setMuted':
          c.setMuted(a[0]);
        case 'useItem':
          c.useItem(a[0], a.length > 1 ? a[1] : null);
        case 'buyAltar':
          c.buyAltar(a[0]);
        case 'merchantBuy':
          c.merchantBuy(a[0]);
        case 'backToTitle':
          c.backToTitle();
        default:
          fail('Unhandled ${f['name']}');
      }
      await storage.settled;
      final actual = {
        'screen': c.screen,
        'game': c.game,
        'modal': c.modal,
        'toasts': c.toasts,
        'floats': c.floats,
        'transition': c.transition,
        'shakeKey': c.shakeKey,
        'slots': c.slots,
        'meta': c.meta
      };
      // Only the approved removal of the first-run keyboard tutorial differs.
      final expected = f['expected'];
      if (expected['modal']?['type'] == 'story') {
        expected['modal']['then'] = null;
      } else if (expected['modal']?['type'] == 'help') {
        expected['modal'] = null;
      }
      expect(canonical(actual), canonical(expected),
          reason: 'Action $i ${f['name']}');
    }
    c.dispose();
  });
}
