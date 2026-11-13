import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game/data.dart';
import '../game/engine.dart';
import '../game_controller.dart';
import 'board.dart';
import 'touch_pad.dart';
import 'theme.dart';

class GameScreen extends StatefulWidget {
  const GameScreen(this.c, {super.key});
  final GameController c;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  (int, int)? selected;
  String position = '';
  GameController get c => widget.c;
  @override
  void didUpdateWidget(GameScreen old) {
    super.didUpdateWidget(old);
    final g = c.game!;
    final next = "${g['floor']}:${g['hero']['x']}:${g['hero']['y']}";
    if (next != position) {
      selected = null;
      position = next;
    }
  }

  Widget header() => SizedBox(
      height: 48,
      child: Row(children: [
        Text('第 ${c.game!['floor']} 层', style: display(19)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(zoneName(c.game!['floor']),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: muted, fontSize: 13))),
        IconButton(
            key: const ValueKey('menu-button'),
            tooltip: '菜单',
            onPressed: () => c.openModal({'type': 'pause'}),
            icon: const Icon(Icons.menu, color: goldSoft),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            padding: EdgeInsets.zero),
      ]));
  Widget stat(String icon, String label, dynamic value,
          {bool colored = false}) =>
      Expanded(
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(children: [
                    art('sprite/$icon', width: 26, height: 26),
                    const SizedBox(width: 4),
                    Text(label,
                        style: TextStyle(
                            fontSize: 14, color: colored ? danger : ink)),
                    const SizedBox(width: 4),
                    Text('$value',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: colored ? danger : ink))
                  ]))));
  Widget stats({bool compact = false}) {
    final h = c.game!['hero'];
    return SizedBox(
        height: compact ? 52 : 68,
        child: Column(children: [
          Container(
              height: compact ? 28 : 36,
              decoration: panel(radius: 6),
              child: Row(children: [
                stat('hp', '生命', h['hp'], colored: true),
                stat('atk', '攻击', h['atk']),
                stat('def', '防御', h['def'])
              ])),
          SizedBox(
              height: compact ? 24 : 32,
              child: Row(children: [
                stat('gold', '', h['gold']),
                for (final id in ['yellowKey', 'blueKey', 'redKey'])
                  Semantics(
                      label: '${c.name(id)} ${h['keys'][id]}',
                      child: SizedBox(
                          width: 56,
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                art('sprite/$id', width: 26, height: 26),
                                Flexible(
                                    child: FittedBox(
                                        child: Text('${h['keys'][id]}',
                                            maxLines: 1,
                                            style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600))))
                              ]))),
              ])),
        ]));
  }

  Widget controls(double size) => Row(
          key: const ValueKey('game-controls'),
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          GameButton('背包',
                              key: const ValueKey('bag-button'),
                              icon: 'sprite/bag',
                              goldFill: true,
                              onPressed: () => c.openModal({'type': 'items'})),
                          const SizedBox(height: 12),
                          GameButton('撤销',
                              key: const ValueKey('undo-button'),
                              onPressed: (c.game!['history'] as List).isEmpty
                                  ? null
                                  : c.undo),
                        ])))),
            const SizedBox(width: 20),
            TouchPad(c, size: size),
          ]);
  Widget board() => Container(
      decoration: panel(
          radius: 2,
          border: gold.withOpacity(.5),
          color: const Color(0xff262726)),
      padding: const EdgeInsets.all(2),
      child: GameBoard(c,
          selected:
              selected == null ? null : cellKey(selected!.$1, selected!.$2),
          onInspect: (x, y) => setState(() => selected = (x, y))));
  Widget inspect({bool compact = false}) {
    final stripHeight = compact
        ? 48.0
        : 56.0 * math.min(1.5, MediaQuery.textScalerOf(context).scale(14) / 14);
    final g = c.game!, w = g['world']['${g['floor']}'];
    var target = selected;
    if (target == null) {
      final fights = c.adjacentFights();
      if (fights.isNotEmpty) {
        target = (fights.first['x'] as int, fights.first['y'] as int);
      }
      for (final id in ['merchant', 'altar']) {
        if (c.nearNpc(id)) {
          final h = g['hero'];
          for (final n in neighbours(h['x'], h['y'])) {
            if (w['ents'][cellKey(n[0], n[1])]?['id'] == id) {
              target = (n[0], n[1]);
              break;
            }
          }
          break;
        }
      }
    }
    if (target == null) return SizedBox(height: stripHeight);
    final x = target.$1, y = target.$2;
    final Obj? e = w['ents'][cellKey(x, y)];
    final pv = c.engine.preview(g, x, y);
    String title, description;
    String? icon;
    VoidCallback? action;
    String? actionLabel;
    Color color = muted;
    if (pv != null) {
      title = pv['monster']['name'];
      icon = 'sprite/${e!['id']}';
      description = pv['canFight'] == true
          ? '预计损失 ${pv['loss']}'
          : pv['reason'] == 'unpierceable'
              ? '无法破防'
              : '生命不足';
      color = pv['canFight'] == true ? goldSoft : danger;
      action = () => c.openModal({'type': 'inspect', 'x': x, 'y': y});
      actionLabel = '详情';
    } else if (e != null) {
      icon = 'sprite/${e['id']}';
      title = {'guide': '引路人', 'altar': '祭坛', 'merchant': '商人'}[e['id']] ??
          c.name(e['id']);
      description = e['kind'] == 'npc'
          ? (c.nearNpc(e['id']) ? '就在身边' : '尚未靠近')
          : (e['kind'] == 'item' ? '道具' : '物品');
      if (['altar', 'merchant'].contains(e['id']) && c.nearNpc(e['id'])) {
        action = () => c.openModal({'type': e['id']});
        actionLabel = e['id'] == 'altar' ? '祭坛' : '交易';
      }
    } else {
      final String t = w['terr'][y][x];
      title = {
            '#': '石墙',
            '.': '通道',
            'y': '黄门',
            'b': '蓝门',
            'r': '红门',
            '%': '裂墙',
            'a': '机关门',
            'w': '假墙',
            '~': '熔岩',
            '*': '虚空',
            '^': '上楼梯',
            'v': '下楼梯'
          }[t] ??
          '通道';
      description = '';
      icon = {
        '^': 'sprite/stair_up',
        'v': 'sprite/stair_down',
        'y': 'sprite/door_y',
        'b': 'sprite/door_b',
        'r': 'sprite/door_r'
      }[t];
    }
    return Container(
        key: const ValueKey('inspect-strip'),
        height: stripHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: panel(border: gold.withOpacity(.45)),
        child: Row(children: [
          if (icon != null) ...[
            art(icon, width: 44, height: 44),
            const SizedBox(width: 8)
          ],
          Expanded(
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        if (description.isNotEmpty)
                          Text(description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: color)),
                      ]))),
          if (action != null)
            TextButton(
                onPressed: action,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(actionLabel!)),
        ]));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final landscape = box.maxWidth > box.maxHeight && box.maxWidth >= 600;
        final padSize = box.maxHeight < 700 ? 152.0 : 164.0;
        if (landscape) {
          final side = math.min(box.maxHeight - 24, box.maxWidth * .48);
          return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                SizedBox(width: side, height: side, child: board()),
                const SizedBox(width: 20),
                Expanded(
                    child: Column(children: [
                  header(),
                  stats(compact: true),
                  const Spacer(),
                  inspect(compact: true),
                  const SizedBox(height: 8),
                  controls(152)
                ]))
              ]));
        }
        return Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Column(children: [
              header(),
              const SizedBox(height: 4),
              stats(),
              const SizedBox(height: 8),
              Expanded(child: LayoutBuilder(builder: (_, space) {
                final side = math.min(space.maxWidth, space.maxHeight);
                return Center(
                    child: SizedBox(width: side, height: side, child: board()));
              })),
              const SizedBox(height: 8),
              inspect(),
              const SizedBox(height: 12),
              controls(padSize),
            ]));
      });
}
