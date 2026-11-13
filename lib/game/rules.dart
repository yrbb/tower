import 'dart:math' as math;
import 'data.dart';

bool hasTrait(Obj m, String type) =>
    (m['traits'] as List? ?? []).any((t) => t['type'] == type);
num effectiveDef(Obj m, [int pillarsAlive = 0]) =>
    hasTrait(m, 'starVeil') ? 280 + 125 * pillarsAlive : m['def'];
num heroAtkVs(Obj hero, Obj m) {
  num atk = hero['atk'];
  if (hasTrait(m, 'sea') && hero['flags']?['tideSpear'] == true) atk *= 2;
  if (hasTrait(m, 'dragon') && hero['flags']?['dragonFang'] == true) atk *= 2;
  return atk;
}

Obj combat(Obj hero, Obj m, {int pillarsAlive = 0}) {
  final perHit = heroAtkVs(hero, m) - effectiveDef(m, pillarsAlive);
  if (perHit <= 0) {
    return {
      'canFight': false,
      'reason': 'unpierceable',
      'perHit': perHit,
      'rounds': null,
      'perRound': null,
      'loss': double.infinity
    };
  }
  final rounds = ((m['hp'] as num) / perHit).ceil();
  num perRound =
      hasTrait(m, 'magic') ? m['atk'] : math.max(0, m['atk'] - hero['def']);
  if (hasTrait(m, 'doubleHit')) perRound *= 2;
  final hits = hasTrait(m, 'firstStrike') ? rounds : rounds - 1;
  final loss = hits * perRound;
  final canFight = loss < hero['hp'];
  return {
    'canFight': canFight,
    'reason': canFight ? null : 'lethal',
    'perHit': perHit,
    'rounds': rounds,
    'perRound': perRound,
    'loss': loss
  };
}

num auraDamage(Obj hero, List adjacentMonsters) {
  if (hero['flags']?['starShield'] == true) return 0;
  num sum = 0;
  for (final m in adjacentMonsters) {
    for (final t in m['traits'] ?? []) {
      if (t['type'] == 'aura') {
        sum += t['damage'] as num;
        break;
      }
    }
  }
  return sum;
}

int zoneOf(int floor) => (floor / 10).ceil();
Obj? consumableEffect(String id, int floor) {
  final z = zoneOf(floor);
  return switch (id) {
    'redCrystal' => {'atk': z + 1},
    'blueCrystal' => {'def': z + 1},
    'redPotion' => {'hp': 50 * z},
    'bluePotion' => {'hp': 150 * z},
    _ => null,
  };
}

const altarTier = {4: 1, 12: 2, 21: 3, 32: 4, 42: 5, 46: 5};
num altarPrice(num k) => 20 * k * k;
Obj? altarGain(int t, String choice) => switch (choice) {
      'hp' => {'hp': 150 * t},
      'atk' => {'atk': 2 * t},
      'def' => {'def': 3 * t},
      _ => null,
    };
