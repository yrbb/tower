import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:star_tower/game/data.dart';
import 'package:star_tower/ui/art_assets.dart';

void main() {
  test('Every game entity and active item has new artwork', () {
    final data =
        GameData.fromJson(File('assets/data/game.json').readAsStringSync());
    for (final table in [
      'MONSTERS',
      'CONSUMABLES',
      'KEYS',
      'GEAR',
      'HOLD',
      'ACTIVE'
    ]) {
      for (final id in data.table(table).keys) {
        expect(spriteIndex.containsKey(id), true, reason: id);
      }
    }
    for (final id in [
      'hero',
      'guide',
      'merchant',
      'altar',
      'gate',
      'stair_up',
      'stair_down'
    ]) {
      expect(spriteIndex.containsKey(id), true, reason: id);
    }
    expect(spriteIndex.length, 80);
    for (final sheet in spriteSheets.keys) {
      expect(File('assets/art/$sheet.png').existsSync(), true);
    }
  });
}
