import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game/data.dart';
import '../game/engine.dart';
import '../game/rules.dart';
import '../game_controller.dart';
import 'theme.dart';

class GameBoard extends StatefulWidget {
  const GameBoard(this.c, {super.key, required this.onInspect, this.selected});
  final void Function(int x, int y) onInspect;
  final String? selected;
  final GameController c;
  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> with TickerProviderStateMixin {
  late final AnimationController idle = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 50400))
    ..repeat();
  late final AnimationController shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320));
  int shakeKey = 0;
  @override
  void didUpdateWidget(GameBoard old) {
    super.didUpdateWidget(old);
    if (widget.c.shakeKey != shakeKey) {
      shakeKey = widget.c.shakeKey;
      shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    idle.dispose();
    shake.dispose();
    super.dispose();
  }

  Widget bounce(Widget child, double period, double amount,
      {double scale = 0}) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedBuilder(
        animation: idle,
        child: child,
        builder: (_, child) {
          final phase =
              (1 - math.cos(idle.value * 50400 / period * math.pi * 2)) / 2;
          return Transform.translate(
              offset: Offset(0, -amount * phase),
              child: Transform.scale(scale: 1 + scale * phase, child: child));
        });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c, g = widget.c.game!;
    final h = g['hero'], w = g['world']['${g['floor']}'];
    final a = c.data.art;
    final tiles = a['ZONE_TILES']['${zoneOf(g['floor'])}'];
    final fights = {
      for (final f in c.adjacentFights()) cellKey(f['x'], f['y']): f['pv']
    };
    return LayoutBuilder(builder: (context, box) {
      final cw = math.max(1.0, math.min(box.maxWidth, box.maxHeight) / 11);
      final ch = cw;
      final cell = math.min(cw, ch);
      final children = <Widget>[];
      for (var y = 0; y < 11; y++) {
        for (var x = 0; x < 11; x++) {
          final String t = w['terr'][y][x];
          final Obj? e = w['ents'][cellKey(x, y)];
          var base =
              ['#', 'w', '%', 'a'].contains(t) ? tiles['wall'] : tiles['floor'];
          if (zoneOf(g['floor']) == 4 && !['#', 'w', '%', 'a'].contains(t)) {
            base = 'tiles/floor_forge';
          }
          if (t == '*') base = 'tiles/floor_void';
          if (t == '~') base = 'tiles/floor_lava';
          final pv = e?['kind'] == 'monster' ? c.engine.preview(g, x, y) : null;
          final adjacent = fights[cellKey(x, y)];
          final parts = <Widget>[
            Positioned.fill(child: art(base, fit: BoxFit.fill))
          ];
          if (a['TERRAIN_ART'][t] != null) {
            parts.add(Positioned.fill(child: art(a['TERRAIN_ART'][t])));
          }
          if (t == 'a') {
            parts.add(Positioned.fill(child: art('sprite/gate')));
          }
          if (t == '%') {
            parts.add(Positioned.fill(child: art('tiles/crack')));
          }
          if (e != null) {
            final id = e['id'];
            Widget entity =
                SizedBox(width: cw, height: ch, child: art('sprite/$id'));
            parts.add(Center(child: entity));
          }
          if (widget.selected == cellKey(x, y)) {
            parts.add(Positioned.fill(
                child: IgnorePointer(
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            border: Border.all(color: goldSoft, width: 2))))));
          }
          if (adjacent != null) {
            parts.add(Positioned.fill(
                child: IgnorePointer(
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            border: Border.all(
                                color: adjacent['canFight'] ? good : danger,
                                width: 2))))));
          }
          if (pv != null) {
            parts.add(Positioned(
                right: 1,
                top: 1,
                child: Container(
                    padding: EdgeInsets.symmetric(horizontal: cell * .08),
                    decoration: BoxDecoration(
                        color: pv['canFight']
                            ? const Color(0xeb239650)
                            : const Color(0xebbe283c),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(
                        pv['canFight']
                            ? '${pv['loss']}'
                            : pv['reason'] == 'unpierceable'
                                ? '×'
                                : '死',
                        style: TextStyle(
                            fontSize: cell * .3,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            height: 1.5)))));
          }
          children.add(Positioned(
              left: x * cw,
              top: y * ch,
              width: cw,
              height: ch,
              child: Semantics(
                label: e != null
                    ? c.name(e['id'])
                    : t == '#'
                        ? '墙'
                        : '地图格 $x,$y',
                child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onInspect(x, y),
                    child: Stack(children: parts)),
              )));
        }
      }
      children.add(AnimatedPositioned(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: const Cubic(.3, .7, .4, 1),
          left: h['x'] * cw,
          top: h['y'] * ch,
          width: cw,
          height: ch,
          child: IgnorePointer(
              child: Padding(
                  padding: EdgeInsets.all(cell * .05),
                  child: bounce(art('hero/hero', label: '勇者'), 1800, 2)))));
      for (final f in c.floats) {
        children.add(Positioned(
            left: f['x'] * cw - cw / 2,
            top: f['y'] * ch + ch * .1,
            width: cw * 2,
            child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                    key: ValueKey(f['id']),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 950),
                    builder: (_, t, __) => Transform.translate(
                        offset: Offset(0, 10 - 44 * t),
                        child: Opacity(
                            opacity: t < .15 ? t / .15 : (1 - t) / .85,
                            child: Text(f['text'],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: cell * .36,
                                    color: danger,
                                    fontWeight: FontWeight.w800))))))));
      }
      final board = SizedBox(
          key: const ValueKey('square-board'),
          width: cw * 11,
          height: ch * 11,
          child: Stack(children: children));
      return Center(
          child: RepaintBoundary(
              child: AnimatedBuilder(
                  animation: shake,
                  child: board,
                  builder: (_, child) {
                    final t = shake.value;
                    const pts = [
                      Offset.zero,
                      Offset(-3, 2),
                      Offset(3, -2),
                      Offset(-2, -1),
                      Offset(2, 1),
                      Offset.zero
                    ];
                    final i = math.min(4, (t * 5).floor());
                    final d = MediaQuery.disableAnimationsOf(context)
                        ? Offset.zero
                        : Offset.lerp(pts[i], pts[i + 1], t * 5 - i)!;
                    return Transform.translate(offset: d, child: child);
                  })));
    });
  }
}
