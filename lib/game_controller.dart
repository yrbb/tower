import 'dart:async';
import 'package:flutter/foundation.dart';
import 'game/data.dart';
import 'game/engine.dart';
import 'services/audio.dart';
import 'services/storage.dart';

const opening = [
  '很久以前，地底矿窖的尽头凿出了一座观星塔。塔一直修到星空里，顶端悬着一张星图。',
  '守塔人把星图锁进了塔顶，塔里的造物也随之失控。你是受雇的修塔匠，要一路上到塔顶，把星幕关掉。',
  '途中你会遇到一位被困的测绘员，她是引路人。她会给你提示，也会记下你走过的检查点。',
];

class GameController extends ChangeNotifier {
  GameController(this.data, this.storage, this.audio)
      : engine = Engine(data),
        meta = storage.loadMeta() {
    audio.setVolume((meta['volume'] as num).toDouble());
    audio.setMuted(meta['muted']);
  }
  final GameData data;
  final Engine engine;
  final SaveStore storage;
  final GameAudio audio;
  final Obj meta;
  String screen = 'title';
  Obj? game, modal, transition;
  final toasts = <Obj>[], floats = <Obj>[];
  int shakeKey = 0, uid = 0;
  num hpPeak = 0;
  bool _disposed = false;
  final _timers = <Timer>{};
  void changed() {
    if (!_disposed) notifyListeners();
  }

  void later(int ms, void Function() action) {
    late Timer timer;
    timer = Timer(Duration(milliseconds: ms), () {
      _timers.remove(timer);
      if (!_disposed) action();
    });
    _timers.add(timer);
  }

  List<Obj> get slots => storage.listSlots();
  String name(String id) => data.name(id);
  void toast(String text, [String tone = 'info']) {
    final id = ++uid;
    toasts.add({'id': id, 'text': text, 'tone': tone});
    if (toasts.length > 4) toasts.removeAt(0);
    later(2600, () {
      toasts.removeWhere((t) => t['id'] == id);
      changed();
    });
    changed();
  }

  void floatAt(String text, String kind) {
    final g = game;
    if (g == null) return;
    final id = ++uid;
    floats.add({
      'id': id,
      'text': text,
      'kind': kind,
      'x': g['hero']['x'],
      'y': g['hero']['y']
    });
    later(1000, () {
      floats.removeWhere((f) => f['id'] == id);
      changed();
    });
  }

  void persistMeta() {
    unawaited(storage.saveMeta(meta));
  }

  void autoSave() {
    if (game != null) {
      unawaited(storage.writeSlot(autoSlot, game!).then((_) => changed()));
    }
  }

  bool fail(Object error) {
    toast('出错了：${error is StateError ? error.message : error}', 'warn');
    return false;
  }

  String gainText(Obj g) => [
        if (g['hp'] != null) '生命 +${g['hp']}',
        if (g['atk'] != null) '攻击 +${g['atk']}',
        if (g['def'] != null) '防御 +${g['def']}'
      ].join(' · ');

  void afterAction(Obj g, int beforeFloor, List events) {
    final says = <String>[];
    var talked = false, won = false;
    String? shop;
    for (final ev in events) {
      switch (ev['type']) {
        case 'fight':
          if (ev['loss'] > 0) {
            floatAt('-${ev['loss']}', 'hurt');
            shakeKey++;
          }
          toast(
              '击败 ${name(ev['id'])} · 损失 ${ev['loss']} 生命 · 金币 +${ev['gold']}',
              'gold');
          audio.effect('hit');
        case 'nofight':
        case 'locked':
          toast(
              ev['type'] == 'locked'
                  ? '需要${data.table('KEYS')[ev['key']]['name']}才能打开'
                  : ev['reason'],
              'warn');
          audio.effect('denied');
        case 'door':
          audio.effect('door');
        case 'false-wall':
          toast('这面墙是假的，已经打通');
          audio.effect('door');
        case 'blocked':
          if (!['前方不能通行', '边界外'].contains(ev['reason'])) {
            toast(ev['reason'], 'warn');
          }
          audio.effect('denied');
        case 'pickup':
          toast('获得 ${name(ev['id'])}', 'gold');
          audio.effect('pick');
        case 'aura':
          floatAt('-${ev['damage']}', 'hurt');
          shakeKey++;
          toast('灼域灼伤 -${ev['damage']} 生命（原始伤害 ${ev['raw']}）', 'warn');
        case 'stair-created':
          toast('一座楼梯出现了', 'gold');
        case 'say':
          says.add(ev['text']);
        case 'talk':
          talked = true;
        case 'shop':
          shop = ev['npc'];
        case 'win':
          won = true;
      }
    }
    if (g['floor'] != beforeFloor) {
      transition = {
        'title': '第 ${g['floor']} 层 · ${zoneName(g['floor'])}',
        'key': ++uid
      };
      later(1600, () {
        transition = null;
        changed();
      });
      audio.effect('stairs');
      audio.music(g['floor']);
      autoSave();
    }
    if (won) {
      audio.stopMusic();
      audio.effect('win');
      modal = {'type': 'ending'};
    } else if (says.isNotEmpty) {
      modal = {
        'type': 'story',
        'title': talked ? '引路人' : '提示',
        'lines': says,
        'then': null
      };
    } else if (talked) {
      toast('引路人：……这里我已经都告诉你了。');
    } else if (shop != null) {
      modal = {'type': shop == 'altar' ? 'altar' : 'merchant'};
    }
    updatePeak();
    changed();
  }

  void updatePeak() {
    if (game != null && game!['hero']['hp'] > hpPeak) {
      hpPeak = game!['hero']['hp'];
    }
  }

  List<Obj> adjacentFights() {
    if (game == null) return [];
    final h = game!['hero'];
    final out = <Obj>[];
    for (final p in neighbours(h['x'], h['y'])) {
      final pv = engine.preview(game!, p[0], p[1]);
      if (pv != null) out.add({'x': p[0], 'y': p[1], 'pv': pv});
    }
    return out;
  }

  bool nearNpc(String id) => game != null && engine.adjacentNpc(game!, id);
  List<int> compassTargets() => game == null
      ? []
      : (game!['visited'] as List)
          .cast<int>()
          .where((f) => f != game!['floor'] && f != 44 && f != 50)
          .toList()
    ..sort();

  void newGame() {
    game = engine.createGame();
    screen = 'playing';
    hpPeak = game!['hero']['hp'];
    final firstTime = meta['seenHelp'] != true;
    if (firstTime) {
      meta['seenHelp'] = true;
      persistMeta();
    }
    modal = {'type': 'story', 'title': '序章', 'lines': opening, 'then': null};
    toasts.clear();
    floats.clear();
    transition = null;
    audio.music(1);
    autoSave();
    changed();
  }

  bool loadSlot(String name) {
    final entry = storage.readSlot(name);
    final st = entry == null ? null : engine.deserialize(entry['state']);
    final valid = st != null &&
        data.maps['${st['floor']}'] != null &&
        (st['world'] as Map).keys.every((k) => data.maps['$k'] != null);
    if (!valid) {
      toast('这个存档无法读取', 'warn');
      return false;
    }
    st['history'] = <dynamic>[];
    game = st;
    hpPeak = st['hero']['hp'];
    screen = 'playing';
    modal = null;
    toasts.clear();
    floats.clear();
    transition = null;
    audio.music(st['floor']);
    toast('已读取存档 · 第 ${st['floor']} 层', 'good');
    changed();
    return true;
  }

  Future<void> saveSlot(String name) async {
    if (game == null) return;
    final ok = await storage.writeSlot(name, game!);
    if (_disposed) return;
    toast(ok ? '存档成功' : '存档失败，请检查手机存储空间', ok ? 'good' : 'warn');
    audio.effect('click');
  }

  Future<void> deleteSlot(String name) async {
    await storage.deleteSlot(name);
    changed();
  }

  void backToTitle() {
    audio.stopMusic();
    audio.music(0);
    screen = 'title';
    game = null;
    modal = null;
    toasts.clear();
    floats.clear();
    transition = null;
    changed();
  }

  bool move(String dir) {
    final g = game;
    if (g == null ||
        screen != 'playing' ||
        modal != null ||
        g['ended'] == true) {
      return false;
    }
    final x = g['hero']['x'], y = g['hero']['y'], floor = g['floor'];
    List<Obj> events;
    try {
      events = engine.moveHero(g, dir);
    } catch (e) {
      return fail(e);
    }
    if (events.first['type'] == 'blocked') {
      afterAction(g, floor, events);
      return false;
    }
    final moved =
        g['hero']['x'] != x || g['hero']['y'] != y || g['floor'] != floor;
    if (moved) audio.effect('move');
    afterAction(g, floor, events);
    return moved;
  }

  bool repeatStep(String dir) {
    final g = game;
    if (g == null) return false;
    final x = g['hero']['x'], y = g['hero']['y'];
    move(dir);
    return modal == null && (g['hero']['x'] != x || g['hero']['y'] != y);
  }

  void undo() {
    final g = game;
    if (g == null || modal != null) return;
    final floor = g['floor'];
    final r = engine.undo(g);
    toast(r['text'], r['ok'] ? 'info' : 'warn');
    if (r['ok'] && g['floor'] != floor) audio.music(g['floor']);
    updatePeak();
    changed();
  }

  bool useItem(String id, [int? target]) {
    final g = game;
    if (g == null || modal != null || g['ended'] == true) return false;
    final int floor = g['floor'];
    Obj res;
    try {
      res = engine.useItem(g, id, target);
    } catch (e) {
      return fail(e);
    }
    if (res['ok'] != true) {
      audio.effect('denied');
      toast(res['text'], 'warn');
      return false;
    }
    audio.effect('click');
    toast(res['text'], 'good');
    afterAction(g, floor, res['events'] ?? []);
    return true;
  }

  bool buyAltar(String choice) {
    if (game == null) return false;
    Obj res;
    try {
      res = engine.buyAltar(game!, choice);
    } catch (e) {
      return fail(e);
    }
    if (res['ok'] != true) {
      audio.effect('denied');
      toast(res['text'], 'warn');
      return false;
    }
    audio.effect('buy');
    toast('${res['text']} · ${gainText(res['gain'])}', 'gold');
    updatePeak();
    changed();
    return true;
  }

  bool merchantBuy(String id) {
    if (game == null) return false;
    Obj res;
    try {
      res = engine.merchantBuy(game!, id);
    } catch (e) {
      return fail(e);
    }
    if (res['ok'] != true) {
      audio.effect('denied');
      toast(res['text'], 'warn');
      return false;
    }
    audio.effect('buy');
    toast(res['text'], 'good');
    updatePeak();
    changed();
    return true;
  }

  void openModal(Obj value) {
    modal = value;
    changed();
  }

  void closeModal() {
    modal = null;
    changed();
  }

  void escape() {
    if (screen != 'playing') return;
    if (modal?['type'] == 'pause') {
      closeModal();
    } else if (modal == null) {
      openModal({'type': 'pause'});
    }
  }

  void setVolume(double value) {
    meta['volume'] = value;
    audio.setVolume(value);
    persistMeta();
    changed();
  }

  void setMuted(bool value) {
    meta['muted'] = value;
    audio.setMuted(value);
    persistMeta();
    changed();
  }

  void titleMusic() {
    if (screen == 'title' && game == null) audio.music(0);
  }

  @override
  void dispose() {
    _disposed = true;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    audio.dispose();
    super.dispose();
  }
}
