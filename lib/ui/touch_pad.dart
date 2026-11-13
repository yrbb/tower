import 'package:flutter/material.dart';
import '../game_controller.dart';
import '../services/hold_repeat.dart';
import 'theme.dart';

class TouchPad extends StatefulWidget {
  const TouchPad(this.c, {super.key, this.size = 160});
  final GameController c;
  final double size;
  @override
  State<TouchPad> createState() => _TouchPadState();
}

class _TouchPadState extends State<TouchPad> with WidgetsBindingObserver {
  final repeaters = <String, HoldRepeat>{};
  final pressed = <String>{};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void stop(String dir) {
    repeaters[dir]?.stop();
    if (mounted) setState(() => pressed.remove(dir));
  }

  void stopAll() {
    for (final r in repeaters.values) {
      r.stop();
    }
    if (mounted) setState(pressed.clear);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) stopAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final r in repeaters.values) {
      r.stop();
    }
    super.dispose();
  }

  Widget direction(String dir, IconData icon, String label, double size) =>
      Semantics(
          label: label,
          button: true,
          onTap: () => widget.c.move(dir),
          child: Listener(
              key: ValueKey('move-$dir'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) {
                setState(() => pressed.add(dir));
                repeaters
                    .putIfAbsent(
                        dir, () => HoldRepeat(() => widget.c.repeatStep(dir)))
                    .start();
              },
              onPointerUp: (_) => stop(dir),
              onPointerCancel: (_) => stop(dir),
              onPointerMove: (e) {
                if (e.localPosition.dx < 0 ||
                    e.localPosition.dy < 0 ||
                    e.localPosition.dx > size ||
                    e.localPosition.dy > size) stop(dir);
              },
              child: AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  decoration: panel(
                      radius: 7,
                      border: goldSoft.withOpacity(.7),
                      gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: pressed.contains(dir)
                              ? [
                                  const Color(0xff756746),
                                  const Color(0xff4b422e)
                                ]
                              : [
                                  const Color(0xff44463d),
                                  const Color(0xff2c302c)
                                ])),
                  child: Icon(icon, size: 30, color: goldSoft))));
  @override
  Widget build(BuildContext context) {
    final cell = (widget.size - 8) / 3;
    return SizedBox(
        key: const ValueKey('direction-pad'),
        width: widget.size,
        height: widget.size,
        child: Stack(children: [
          Positioned(
              left: cell + 4,
              top: 0,
              width: cell,
              height: cell,
              child: direction('up', Icons.arrow_drop_up, '向上', cell)),
          Positioned(
              left: 0,
              top: cell + 4,
              width: cell,
              height: cell,
              child: direction('left', Icons.arrow_left, '向左', cell)),
          Positioned(
              right: 0,
              top: cell + 4,
              width: cell,
              height: cell,
              child: direction('right', Icons.arrow_right, '向右', cell)),
          Positioned(
              left: cell + 4,
              bottom: 0,
              width: cell,
              height: cell,
              child: direction('down', Icons.arrow_drop_down, '向下', cell)),
        ]));
  }
}
