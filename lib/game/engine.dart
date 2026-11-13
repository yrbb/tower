import 'dart:convert';
import 'dart:math' as math;
import 'data.dart';
import 'rules.dart';

const dirs = <String, List<int>>{
  'up': [0, -1],
  'down': [0, 1],
  'left': [-1, 0],
  'right': [1, 0]
};
const doors = {'y': 'yellowKey', 'b': 'blueKey', 'r': 'redKey'};
const terrain = {'.', '#', '%', 'w', '~', '*', 'y', 'b', 'r', 'a', '^', 'v'};
bool inBounds(int x, int y) => x >= 0 && y >= 0 && x < 11 && y < 11;
String cellKey(int x, int y) => '$x,$y';
List<List<int>> neighbours(int x, int y) => dirs.values
    .map((d) => [x + d[0], y + d[1]])
    .where((p) => inBounds(p[0], p[1]))
    .toList();

class Engine {
  Engine(this.data, {Obj? definitions}) : defs = definitions ?? data.maps;
  final GameData data;
  final Obj defs;
  Obj get monsters => data.table('MONSTERS');
  Obj get active => data.table('ACTIVE');

  Obj instantiate(Obj def) {
    final terr = <List<String>>[];
    final ents = <String, dynamic>{};
    for (var y = 0; y < (def['grid'] as List).length; y++) {
      final row = (def['grid'][y] as String).split('');
      terr.add(row.map((c) => terrain.contains(c) ? c : '.').toList());
      for (var x = 0; x < row.length; x++) {
        final c = row[x];
        if (terrain.contains(c)) continue;
        final id = def['legend'][c];
        if (id == null || id == '') {
          throw StateError('第 ${def['index']} 层 ($x,$y) 的字符 "$c" 没有图例');
        }
        final kind = monsters[id] != null
            ? 'monster'
            : ['guide', 'merchant', 'altar'].contains(id)
                ? 'npc'
                : 'item';
        ents[cellKey(x, y)] = {'kind': kind, 'id': id};
      }
    }
    return {'terr': terr, 'ents': ents};
  }

  Obj ensureFloor(Obj state, int n) {
    final world = state['world'];
    if (world['$n'] == null) {
      if (defs['$n'] == null) throw StateError('没有第 $n 层的定义');
      world['$n'] = instantiate(defs['$n']);
    }
    return world['$n'];
  }

  Obj? counterpart(Obj state, int target, String want, int x, int y) {
    final w = ensureFloor(state, target);
    for (final d in [
      [0, 0],
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1]
    ]) {
      final cx = x + d[0], cy = y + d[1];
      if (inBounds(cx, cy) && w['terr'][cy][cx] == want) {
        return {'floor': target, 'x': cx, 'y': cy};
      }
    }
    return null;
  }

  Obj landing(Obj state, int floor, int sx, int sy) {
    final w = ensureFloor(state, floor);
    for (final p in neighbours(sx, sy)) {
      if (w['terr'][p[1]][p[0]] == '.' &&
          w['ents'][cellKey(p[0], p[1])] == null) return {'x': p[0], 'y': p[1]};
    }
    throw StateError('第 $floor 层楼梯 ($sx,$sy) 旁没有空地可以落脚');
  }

  Obj createGame({int startFloor = 1}) {
    final def = defs['$startFloor'];
    final state = <String, dynamic>{
      'version': 1,
      'floor': startFloor,
      'hero': {
        'x': def['entry']['x'],
        'y': def['entry']['y'],
        'hp': 1000,
        'atk': 10,
        'def': 10,
        'gold': 0,
        'keys': {'yellowKey': 0, 'blueKey': 0, 'redKey': 0},
        'flags': {
          'tideSpear': false,
          'charm': false,
          'dragonFang': false,
          'starShield': false
        }
      },
      'items': <String, dynamic>{},
      'altarBuys': 0,
      'world': <String, dynamic>{},
      'firedEvents': <dynamic>[],
      'visited': <dynamic>[startFloor],
      'soldOut': <dynamic>[],
      'dead': false,
      'ended': false,
      'history': <dynamic>[],
    };
    ensureFloor(state, startFloor);
    return state;
  }

  String bodyJson(Obj state) => jsonEncode(Map.of(state)..remove('history'));
  void settle(Obj state, String before) {
    final List history = state['history'];
    // Preserve upstream e41439a: a no-op removes the preceding undo record.
    if (bodyJson(state) == before) {
      if (history.isNotEmpty) history.removeLast();
    } else {
      history.add(before);
      if (history.length > 50) history.removeAt(0);
    }
  }

  Obj undo(Obj state) {
    final List history = state['history'];
    if (history.isEmpty) return {'ok': false, 'text': '没有可以撤销的操作'};
    final restored = jsonDecode(history.removeLast() as String) as Obj;
    state
      ..clear()
      ..addAll(restored)
      ..['history'] = history;
    return {'ok': true, 'text': '已撤销一步'};
  }

  Obj? entityAt(Obj state, int x, int y) =>
      ensureFloor(state, state['floor'])['ents'][cellKey(x, y)];
  int livingPillars(Obj state) {
    if (defs['49'] == null) return 4;
    return (ensureFloor(state, 49)['ents'] as Map)
        .values
        .where((e) => e['id'] == 'pillarGuard')
        .length;
  }

  Obj? preview(Obj state, int x, int y) {
    final e = entityAt(state, x, y);
    if (e == null || e['kind'] != 'monster') return null;
    final pillars = e['id'] == 'endLord' ? livingPillars(state) : 0;
    return {
      'id': e['id'],
      'monster': monsters[e['id']],
      ...combat(state['hero'], monsters[e['id']], pillarsAlive: pillars)
    };
  }

  void checkEvents(Obj state, Obj ctx, List<Obj> out) {
    for (final ev in defs['${state['floor']}']?['events'] ?? []) {
      if ((state['firedEvents'] as List).contains(ev['id'])) continue;
      final t = ev['trigger'];
      var ok = false;
      if (t['op'] == 'talked') ok = ctx['talked'] == t['npc'];
      if (t['op'] == 'enterTile') {
        ok = ctx['entered'] != null &&
            ctx['entered']['x'] == t['at']['x'] &&
            ctx['entered']['y'] == t['at']['y'];
      }
      if (t['op'] == 'defeated') {
        ok = ctx['defeated'] != null &&
            ctx['defeated']['x'] == t['at']['x'] &&
            ctx['defeated']['y'] == t['at']['y'];
      }
      if (t['op'] == 'allDefeated') {
        final w = ensureFloor(state, state['floor']);
        ok = (t['at'] as List).every(
            (p) => w['ents'][cellKey(p['x'], p['y'])]?['kind'] != 'monster');
      }
      if (!ok) continue;
      state['firedEvents'].add(ev['id']);
      for (final eff in ev['effects']) {
        applyEffect(state, eff, out);
      }
    }
  }

  void applyEffect(Obj state, Obj eff, List<Obj> out) {
    final w = ensureFloor(state, state['floor']);
    switch (eff['op']) {
      case 'setTerrain':
        w['terr'][eff['y']][eff['x']] = eff['terrain'];
      case 'addStair':
        w['terr'][eff['y']][eff['x']] = eff['dir'] == 'up' ? '^' : 'v';
        out.add({
          'type': 'stair-created',
          'x': eff['x'],
          'y': eff['y'],
          'dir': eff['dir']
        });
      case 'spawnItem':
        w['ents']
            [cellKey(eff['x'], eff['y'])] = {'kind': 'item', 'id': eff['id']};
      case 'grantItem':
        grantItem(state, eff['id'], out);
      case 'say':
        out.add({'type': 'say', 'text': eff['text']});
      case 'win':
        state['ended'] = true;
        out.add({'type': 'win'});
      default:
        throw StateError('未知事件效果 ${eff['op']}');
    }
  }

  void grantItem(Obj state, String id, List<Obj> out) {
    final hero = state['hero'];
    if (data.table('CONSUMABLES')[id] != null) {
      final e = consumableEffect(id, state['floor'])!;
      for (final k in ['atk', 'def', 'hp']) {
        if (e[k] != null) hero[k] += e[k];
      }
    } else if (data.table('KEYS')[id] != null) {
      hero['keys'][id] += 1;
    } else if (data.table('GEAR')[id] != null) {
      final g = data.table('GEAR')[id];
      for (final k in ['atk', 'def']) {
        if (g[k] != null) hero[k] += g[k];
      }
      if (g['immuneAura'] == true) hero['flags']['starShield'] = true;
    } else if (data.table('HOLD')[id] != null) {
      hero['flags'][data.table('HOLD')[id]['flag']] = true;
    } else if (active[id] != null) {
      state['items'][id] = (state['items'][id] ?? 0) + 1;
    } else {
      throw StateError('未知道具 $id');
    }
    out.add({'type': 'pickup', 'id': id});
  }

  void auraStep(Obj state, List<Obj> out) {
    final w = ensureFloor(state, state['floor']);
    final hero = state['hero'];
    final adj = <Obj>[];
    for (final d in dirs.values) {
      final e = w['ents'][cellKey(hero['x'] + d[0], hero['y'] + d[1])];
      if (e != null && e['kind'] == 'monster') adj.add(monsters[e['id']]);
    }
    final raw = auraDamage(hero, adj);
    if (raw > 0) {
      final num before = hero['hp'];
      hero['hp'] = math.max(1, before - raw);
      out.add({'type': 'aura', 'damage': before - hero['hp'], 'raw': raw});
    }
  }

  List<Obj> moveHero(Obj state, String dir) {
    if (state['dead'] == true || state['ended'] == true) {
      return [
        {'type': 'blocked', 'reason': '游戏已结束'}
      ];
    }
    final delta = dirs[dir];
    if (delta == null) {
      return [
        {'type': 'blocked', 'reason': '无效方向'}
      ];
    }
    final before = bodyJson(state);
    final out = <Obj>[];
    final result = step(state, delta, out);
    settle(state, before);
    return [result, ...out.where((o) => !identical(o, result))];
  }

  Obj step(Obj state, List<int> delta, List<Obj> out) {
    final hero = state['hero'];
    final int nx = hero['x'] + delta[0], ny = hero['y'] + delta[1];
    if (!inBounds(nx, ny)) return {'type': 'blocked', 'reason': '边界外'};
    final w = ensureFloor(state, state['floor']);
    final t = w['terr'][ny][nx];
    final e = w['ents'][cellKey(nx, ny)];
    if (['#', '%', '~', '*'].contains(t)) {
      return {'type': 'blocked', 'reason': '前方不能通行'};
    }
    if (t == 'w') {
      w['terr'][ny][nx] = '.';
      return {'type': 'false-wall', 'x': nx, 'y': ny};
    }
    if (doors.containsKey(t)) {
      final k = doors[t]!;
      if (hero['keys'][k] <= 0) {
        return {
          'type': 'locked',
          'key': k,
          'reason': '需要${data.table('KEYS')[k]['name']}才能打开'
        };
      }
      hero['keys'][k] -= 1;
      w['terr'][ny][nx] = '.';
      return {'type': 'door', 'key': k};
    }
    if (t == 'a') return {'type': 'blocked', 'reason': '机关门，需要触发机关'};
    if (e != null && e['kind'] == 'monster') {
      final p = preview(state, nx, ny)!;
      if (p['canFight'] != true) {
        return {
          'type': 'nofight',
          'reason':
              p['reason'] == 'unpierceable' ? '无法破防：攻击不大于防御' : '会死亡：损失不小于当前生命'
        };
      }
      hero['hp'] -= p['loss'];
      final gold =
          monsters[e['id']]['gold'] * (hero['flags']['charm'] == true ? 2 : 1);
      hero['gold'] += gold;
      w['ents'].remove(cellKey(nx, ny));
      out.add({'type': 'defeated', 'id': e['id'], 'x': nx, 'y': ny});
      if (e['id'] == 'endLord') {
        state['ended'] = true;
        out.add({'type': 'win'});
      }
      checkEvents(
          state,
          {
            'defeated': {'x': nx, 'y': ny}
          },
          out);
      return {'type': 'fight', 'id': e['id'], 'loss': p['loss'], 'gold': gold};
    }
    if (e != null && e['kind'] == 'npc') {
      if (e['id'] == 'guide') {
        checkEvents(state, {'talked': 'guide'}, out);
        return {'type': 'talk', 'npc': 'guide'};
      }
      return {'type': 'shop', 'npc': e['id']};
    }
    hero['x'] = nx;
    hero['y'] = ny;
    if (e != null && e['kind'] == 'item') {
      w['ents'].remove(cellKey(nx, ny));
      grantItem(state, e['id'], out);
    }
    checkEvents(
        state,
        {
          'entered': {'x': nx, 'y': ny}
        },
        out);
    if (t == '^' || t == 'v') {
      final dir = t == '^' ? 'up' : 'down';
      final int target = defs['${state['floor']}']['stairTo']
              ?[cellKey(nx, ny)] ??
          (state['floor'] + (dir == 'up' ? 1 : -1));
      final cp = counterpart(state, target, dir == 'up' ? 'v' : '^', nx, ny);
      final at = cp != null
          ? landing(state, cp['floor'], cp['x'], cp['y'])
          : defs['$target']['entry'];
      ensureFloor(state, target);
      state['floor'] = target;
      if (!(state['visited'] as List).contains(target)) {
        state['visited'].add(target);
      }
      hero['x'] = at['x'];
      hero['y'] = at['y'];
      auraStep(state, out);
      return {'type': 'stairs', 'floor': target, 'dir': dir};
    }
    auraStep(state, out);
    return {'type': 'moved'};
  }

  bool adjacentNpc(Obj state, String id) {
    final w = ensureFloor(state, state['floor']);
    return neighbours(state['hero']['x'], state['hero']['y'])
        .any((p) => w['ents'][cellKey(p[0], p[1])]?['id'] == id);
  }

  Obj buyAltar(Obj state, String choice) {
    final t = altarTier[state['floor']];
    if (t == null || !adjacentNpc(state, 'altar')) {
      return {'ok': false, 'text': '需要站在祭坛旁边'};
    }
    if (!['hp', 'atk', 'def'].contains(choice)) {
      return {'ok': false, 'text': '未知选项'};
    }
    final price = altarPrice(state['altarBuys'] + 1);
    if (state['hero']['gold'] < price) {
      return {'ok': false, 'text': '金币不足，需要 $price'};
    }
    final before = bodyJson(state);
    state['hero']['gold'] -= price;
    state['altarBuys'] += 1;
    final g = altarGain(t, choice)!;
    for (final k in ['hp', 'atk', 'def']) {
      if (g[k] != null) state['hero'][k] += g[k];
    }
    settle(state, before);
    return {
      'ok': true,
      'text': '第 ${state['altarBuys']} 次购买，花费 $price',
      'gain': g
    };
  }

  Obj merchantBuy(Obj state, String shopId) {
    final List list = data.table('MERCHANTS')['${state['floor']}'] ?? [];
    Obj? item;
    for (final s in list) {
      if (s['id'] == shopId) {
        item = s;
        break;
      }
    }
    if (item == null) return {'ok': false, 'text': '这里没有这件商品'};
    if (!adjacentNpc(state, 'merchant')) {
      return {'ok': false, 'text': '需要站在商人旁边'};
    }
    if (item['unlimited'] != true &&
        (state['soldOut'] as List).contains(shopId)) {
      return {'ok': false, 'text': '已经售完'};
    }
    final before = bodyJson(state);
    final hero = state['hero'];
    if (item['recycle'] != null) {
      if (hero['keys'][item['recycle']] <= 0) {
        return {'ok': false, 'text': '没有可以回收的钥匙'};
      }
      hero['keys'][item['recycle']] -= 1;
      hero['gold'] += item['gold'];
      settle(state, before);
      return {'ok': true, 'text': '回收了一把钥匙，获得 ${item['gold']} 金币'};
    }
    if (hero['gold'] < item['price']) {
      return {'ok': false, 'text': '金币不足，需要 ${item['price']}'};
    }
    hero['gold'] -= item['price'];
    state['soldOut'].add(shopId);
    if (item['hp'] != null) hero['hp'] += item['hp'];
    for (final e in (item['items'] as Map? ?? {}).entries) {
      if (data.table('KEYS')[e.key] != null) {
        hero['keys'][e.key] += e.value;
      } else {
        state['items'][e.key] = (state['items'][e.key] ?? 0) + e.value;
      }
    }
    settle(state, before);
    return {'ok': true, 'text': '购买成功，花费 ${item['price']}'};
  }

  Obj useItem(Obj state, String id, [int? target]) {
    final def = active[id];
    if (def == null) return {'ok': false, 'text': '这件道具不能主动使用'};
    if ((state['items'][id] ?? 0) <= 0) {
      return {'ok': false, 'text': '没有${def['name']}'};
    }
    final before = bodyJson(state);
    final w = ensureFloor(state, state['floor']);
    final hero = state['hero'];
    final out = <Obj>[];
    var text = '';
    switch (id) {
      case 'compass':
        if (state['floor'] == 50) {
          return {'ok': false, 'text': '第 50 层不能使用传送罗盘'};
        }
        if (!(state['visited'] as List).contains(target)) {
          return {'ok': false, 'text': '只能传送到已到过的楼层'};
        }
        if (target == 44 || target == 50) {
          return {'ok': false, 'text': '罗盘不能传送到第 44、50 层'};
        }
        ensureFloor(state, target!);
        state['floor'] = target;
        hero['x'] = defs['$target']['entry']['x'];
        hero['y'] = defs['$target']['entry']['y'];
        text = '传送到第 $target 层';
      case 'pickaxe':
        final hits = neighbours(hero['x'], hero['y'])
            .where((p) => w['terr'][p[1]][p[0]] == '%');
        if (hits.isEmpty) return {'ok': false, 'text': '周围没有裂墙'};
        final hit = hits.first;
        w['terr'][hit[1]][hit[0]] = '.';
        text = '凿开了一面裂墙';
      case 'flask':
        hero['hp'] *= 2;
        text = '生命翻倍，现为 ${hero['hp']}';
      case 'mirrorJump':
        final int nx = 10 - (hero['x'] as int), ny = 10 - (hero['y'] as int);
        if (w['terr'][ny][nx] != '.' || w['ents'][cellKey(nx, ny)] != null) {
          return {'ok': false, 'text': '对称位置不是没有东西的空地'};
        }
        hero['x'] = nx;
        hero['y'] = ny;
        text = '镜面跃迁到 ($nx, $ny)';
      case 'frostCore':
        var n = 0;
        for (final row in w['terr']) {
          for (var x = 0; x < (row as List).length; x++) {
            if (row[x] == '~') {
              row[x] = '.';
              n++;
            }
          }
        }
        if (n == 0) return {'ok': false, 'text': '本层没有熔岩'};
        text = '清除了 $n 格熔岩';
      case 'bomb':
        var n = 0;
        for (final p in neighbours(hero['x'], hero['y'])) {
          final e = w['ents'][cellKey(p[0], p[1])];
          if (e != null &&
              e['kind'] == 'monster' &&
              monsters[e['id']]['boss'] != true) {
            w['ents'].remove(cellKey(p[0], p[1]));
            n++;
            out.add({
              'type': 'defeated',
              'id': e['id'],
              'x': p[0],
              'y': p[1],
              'bomb': true
            });
            checkEvents(
                state,
                {
                  'defeated': {'x': p[0], 'y': p[1]}
                },
                out);
          }
        }
        if (n == 0) return {'ok': false, 'text': '周围没有可以炸的怪物'};
        checkEvents(state, {}, out);
        text = '炸掉了 $n 只怪物（不给金币）';
      default:
        return {'ok': false, 'text': '未实现'};
    }
    if (def['uses'] != double.infinity) state['items'][id] -= 1;
    settle(state, before);
    return {'ok': true, 'text': text, 'events': out};
  }

  String serialize(Obj state) => jsonEncode(state);
  Obj? deserialize(dynamic text) {
    try {
      final obj = text is String ? jsonDecode(text) : text;
      if (obj is! Map<String, dynamic> ||
          obj['version'] != 1 ||
          !jsTruthy(obj['hero']) ||
          !jsTruthy(obj['world'])) return null;
      return obj;
    } catch (_) {
      return null;
    }
  }
}
