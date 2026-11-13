import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:star_tower/app.dart';
import 'package:star_tower/game/data.dart';
import 'package:star_tower/game_controller.dart';
import 'package:star_tower/services/audio.dart';
import 'package:star_tower/services/storage.dart';
import 'package:star_tower/ui/modals.dart';

Future<GameController> controller() async {
  final data =
      GameData.fromJson(File('assets/data/game.json').readAsStringSync());
  final storage = SaveStore(MemoryBackend());
  await storage.init();
  return GameController(data, storage, SilentAudio());
}

void main() {
  testWidgets('Touch controls, inspection, native back and save compatibility',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = await controller();
    await tester.pumpWidget(StarTowerApp(c));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('new-game')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(c.modal?['type'], 'story');
    final start = [c.game!['hero']['x'], c.game!['hero']['y']];
    c.move('left');
    expect([c.game!['hero']['x'], c.game!['hero']['y']], start);
    await tester.tap(find.text('跳过全部'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(c.modal, null);
    expect(find.text('操作说明'), findsNothing);
    final board = tester.getRect(find.byKey(const ValueKey('square-board')));
    expect(board.width, closeTo(board.height, .01));
    expect(
        tester.getCenter(find.byKey(const ValueKey('bag-button'))).dx,
        lessThan(
            tester.getCenter(find.byKey(const ValueKey('direction-pad'))).dx));
    // Inspect a distant tile without moving, fighting or adding undo history.
    final snapshot = c.engine.bodyJson(c.game!);
    await tester.tapAt(board.topLeft +
        Offset(board.width * 3.5 / 11, board.height * 10.5 / 11));
    await tester.pump(const Duration(milliseconds: 250));
    expect(c.engine.bodyJson(c.game!), snapshot);
    expect(find.text('预计损失 12'), findsOneWidget);
    await tester.tap(find.text('详情'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(c.modal?['type'], 'inspect');
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 250));
    expect(c.modal, null);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('move-left')));
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(c.game!['hero']['hp'], 988);
    expect(c.game!['hero']['gold'], 1);
    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(c.game!['hero']['hp'], 1000);
    await tester.tap(find.byKey(const ValueKey('menu-button')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('存档'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('save-0')));
    await tester.pump();
    expect(c.storage.readSlot('0'), isNotNull);
    c.closeModal();
    c.game!['hero']['hp'] = 8;
    expect(c.loadSlot('0'), true);
    expect(c.game!['hero']['hp'], 1000);
    expect(c.game!['history'], isEmpty);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('bag-button')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(c.modal?['type'], 'items');
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 250));
    expect(c.modal, null);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 250));
    expect(c.modal?['type'], 'pause');
    await tester.tap(find.text('返回首页'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(c.screen, 'title');
    expect(c.game, null);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
  for (final size in [
    const Size(375, 812),
    const Size(320, 568),
    const Size(812, 375)
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('All screens fit ${size.width} x ${size.height}, text $scale',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = size.width > size.height
            ? const FakeViewPadding(left: 24, right: 24, top: 24, bottom: 24)
            : const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final c = await controller();
        await tester.pumpWidget(StarTowerApp(c));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), null);
        c.newGame();
        c.closeModal();
        c.closeModal();
        await tester.pump(const Duration(milliseconds: 250));
        expect(tester.takeException(), null);
        for (final dir in ['up', 'down', 'left', 'right']) {
          final size = tester.getSize(find.byKey(ValueKey('move-$dir')));
          expect(size.shortestSide, greaterThanOrEqualTo(48));
        }
        c.game!['items'] = {
          for (final id in c.data.table('ACTIVE').keys) id: 1
        };
        for (final type in [
          'pause',
          'settings',
          'saves',
          'compass',
          'items',
          'altar',
          'merchant',
          'ending',
          'inspect'
        ]) {
          c.openModal({'type': type, 'mode': 'save', 'x': 3, 'y': 10});
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          expect(tester.takeException(), null, reason: type);
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('Battle details use current star-veil defense', (tester) async {
    final c = await controller();
    c.newGame();
    c.closeModal();
    c.game!['floor'] = 50;
    final world = c.engine.ensureFloor(c.game!, 50);
    final boss = (world['ents'] as Map)
        .entries
        .firstWhere((e) => e.value['id'] == 'endLord');
    final xy = (boss.key as String).split(',').map(int.parse).toList();
    c.openModal({'type': 'inspect', 'x': xy[0], 'y': xy[1]});
    await tester.pumpWidget(StarTowerApp(c));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('防御 780'), findsOneWidget);
    final pillars = c.engine.ensureFloor(c.game!, 49)['ents'] as Map;
    pillars.removeWhere((_, e) => e['id'] == 'pillarGuard');
    c.changed();
    await tester.pump();
    expect(find.textContaining('防御 280'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Story text typing, finish sentence, next and skip',
      (tester) async {
    var done = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StoryBox(
                title: '剧情', lines: const ['甲乙', '丙'], onDone: () => done++))));
    await tester.pump(const Duration(milliseconds: 34));
    expect(find.text('甲▍'), findsOneWidget);
    await tester.tap(find.text('看完本句'));
    await tester.pump();
    expect(find.text('甲乙'), findsOneWidget);
    await tester.tap(find.text('下一句 ▸'));
    await tester.pump(const Duration(milliseconds: 34));
    await tester.tap(find.text('继续'));
    expect(done, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
