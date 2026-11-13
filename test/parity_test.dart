import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:star_tower/game/data.dart';
import 'package:star_tower/game/engine.dart';
import 'package:star_tower/game/rules.dart';

dynamic canonical(dynamic value) {
  if (value is double && value.isInfinite) return {r'$number': 'Infinity'};
  if (value is Map) return value.map((k, v) => MapEntry(k, canonical(v)));
  if (value is List) return value.map(canonical).toList();
  if (value is String && value.startsWith('{')) {
    try {
      return canonical(jsonDecode(value));
    } catch (_) {}
  }
  return value;
}

void main() {
  final data =
      GameData.fromJson(File('assets/data/game.json').readAsStringSync());
  final corpus = jsonDecode(utf8.decode(
      gzip.decode(File('test/fixtures/reference.json.gz').readAsBytesSync())));
  final List calls = corpus['calls'];
  for (final group in ['engine', 'rules']) {
    test(
        'Pinned JS $group parity (${calls.where((c) => c['group'] == group).length} calls)',
        () {
      for (var i = 0; i < calls.length; i++) {
        final c = calls[i];
        if (c['group'] != group) continue;
        final List a = c['args'];
        final e = Engine(data,
            definitions:
                c['defId'] == null ? null : corpus['defs'][c['defId']]);
        dynamic result;
        String? error;
        try {
          if (group == 'engine') {
            result = switch (c['name']) {
              'createGame' => e.createGame(
                  startFloor: a.isEmpty ? 1 : a[0]['startFloor'] ?? 1),
              'moveHero' => e.moveHero(a[0], a[1]),
              'buyAltar' => e.buyAltar(a[0], a[1]),
              'merchantBuy' => e.merchantBuy(a[0], a[1]),
              'useItem' => e.useItem(a[0], a[1], a.length > 2 ? a[2] : null),
              'preview' => e.preview(a[0], a[1], a[2]),
              'undo' => e.undo(a[0]),
              'serialize' => e.serialize(a[0]),
              'deserialize' => e.deserialize(a[0]),
              _ => throw StateError('Missing adapter: ${c['name']}'),
            };
          } else {
            result = switch (c['name']) {
              'combat' => combat(a[0], a[1],
                  pillarsAlive: a.length > 2 ? a[2]['pillarsAlive'] ?? 0 : 0),
              'auraDamage' => auraDamage(a[0], a[1]),
              'effectiveDef' => effectiveDef(a[0], a.length > 1 ? a[1] : 0),
              'consumableEffect' => consumableEffect(a[0], a[1]),
              'altarPrice' => altarPrice(a[0]),
              'altarGain' => altarGain(a[0], a[1]),
              'zoneOf' => zoneOf(a[0]),
              _ => throw StateError('Missing adapter: ${c['name']}'),
            };
          }
        } catch (e) {
          error = e is StateError ? e.message : e.toString();
        }
        expect(error, c['error'], reason: '#$i ${c['name']} exception');
        expect(canonical(result), canonical(c['result']),
            reason: '#$i ${c['name']} result');
        if (c['state'] != null) {
          expect(canonical(a[0]), canonical(c['state']),
              reason: '#$i ${c['name']} state');
        }
      }
    });
  }
  test('Upstream blocked move consumes previous undo record', () {
    final e = Engine(data);
    final s = e.createGame();
    s['hero']['x'] = 5;
    s['hero']['y'] = 5;
    s['world']['1']['terr'][5][6] = '.';
    s['world']['1']['ents'].remove('6,5');
    s['world']['1']['terr'][4][6] = '#';
    e.moveHero(s, 'right');
    expect(s['history'], hasLength(1));
    e.moveHero(s, 'up');
    expect(s['history'], isEmpty);
    expect(e.undo(s)['ok'], false);
  });
}
