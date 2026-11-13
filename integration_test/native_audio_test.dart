import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:star_tower/app.dart';
import 'package:star_tower/ui/art_assets.dart';
import 'package:star_tower/ui/modals.dart';
import 'package:star_tower/game/data.dart';
import 'package:star_tower/game_controller.dart';
import 'package:star_tower/services/audio.dart';
import 'package:star_tower/services/storage.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Native audio completion, repeated effects and floor changes',
      (tester) async {
    final data =
        GameData.fromJson(await rootBundle.loadString('assets/data/game.json'));
    final manifest =
        jsonDecode(await rootBundle.loadString('assets/data/audio.json'));
    final storage = SaveStore(MemoryBackend());
    await storage.init();
    final audio = NativeAudio(manifest);
    final c = GameController(data, storage, audio);
    await tester.pumpWidget(StarTowerApp(c));
    await audio.prepareEffects();
    await tester.pump(const Duration(seconds: 2));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await binding.takeScreenshot('mota-title');
    c.titleMusic();
    for (var i = 0; i < 40; i++) {
      audio.effect('click');
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.tap(find.byKey(const ValueKey('new-game')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('跳过全部'));
    await tester.pump(const Duration(seconds: 1));
    expect(c.modal, null);
    final board = tester.getRect(find.byKey(const ValueKey('square-board')));
    expect(board.width, closeTo(board.height, .01));
    expect(
        tester.getCenter(find.byKey(const ValueKey('bag-button'))).dx,
        lessThan(
            tester.getCenter(find.byKey(const ValueKey('direction-pad'))).dx));
    await tester.tap(find.byKey(const ValueKey('move-left')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await binding.takeScreenshot('mota-game');
    await tester.tap(find.byKey(const ValueKey('move-left')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.game!['hero']['hp'], 988);
    expect(c.game!['hero']['gold'], 1);
    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.game!['hero']['hp'], 1000);
    await tester.tap(find.byKey(const ValueKey('menu-button')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('存档'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('save-0')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(storage.readSlot('0'), isNotNull);
    c.closeModal();
    c.game!['hero']['hp'] = 1;
    expect(c.loadSlot('0'), true);
    expect(c.game!['hero']['hp'], 1000);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('bag-button')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(c.modal?['type'], 'items');
    c.game!['items'] = {
      for (final id in ['compass', 'pickaxe', 'flask', 'mirrorJump']) id: 1
    };
    c.changed();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('背包是空的。'), findsNothing);
    for (final sprite in tester.widgetList<SpriteArt>(find.descendant(
        of: find.byType(GameModals), matching: find.byType(SpriteArt)))) {
      final finder = find.byWidget(sprite);
      expect(tester.getSize(finder), const Size(52, 52));
      expect(find.descendant(of: finder, matching: find.byType(CustomPaint)),
          findsOneWidget);
    }
    await binding.takeScreenshot('mota-bag');
    await tester.tap(find.byTooltip('关闭'));
    await tester.pump(const Duration(milliseconds: 250));
    for (var i = 0; i < 60; i++) {
      c.move(['left', 'up', 'right', 'down'][(i ~/ 3) % 4]);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    }
    for (final floor in [10, 11, 20, 21, 30, 31, 40, 41, 50, 0]) {
      audio.music(floor);
      audio.effect('click');
      await tester.pump(const Duration(milliseconds: 650));
    }
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(audio.outputVolume, 0);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(audio.outputVolume, greaterThan(0));
    for (var i = 0; i < 20; i++) {
      audio.effect('click');
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(c.game, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: Text('测试完成，请打开正式版「魔塔」')))));
    await tester.pump(const Duration(seconds: 2));
  });
}
