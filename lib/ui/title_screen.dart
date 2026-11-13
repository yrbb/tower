import 'package:flutter/material.dart';
import '../game_controller.dart';
import '../services/storage.dart';
import 'theme.dart';

const homeBackgroundImage = AssetImage('assets/art/title.png');

class TitleScreen extends StatelessWidget {
  const TitleScreen(this.c, {super.key});
  final GameController c;
  Widget actions() {
    final auto = c.storage.readSlot(autoSlot);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (auto != null) ...[
        GameButton('继续冒险',
            key: const ValueKey('continue-game'),
            goldFill: true,
            height: 58,
            fontSize: 20,
            onPressed: () => c.loadSlot(autoSlot)),
        const SizedBox(height: 14)
      ],
      GameButton('开始新游戏',
          key: const ValueKey('new-game'),
          goldFill: auto == null,
          height: 58,
          fontSize: 20,
          onPressed: c.newGame),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: TextButton.icon(
                onPressed: () => c.openModal({'type': 'saves', 'mode': 'load'}),
                icon: const Icon(Icons.save_outlined, size: 19),
                label: const Text('存档'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)))),
        Container(width: 1, height: 16, color: line),
        Expanded(
            child: TextButton.icon(
                onPressed: () => c.openModal({'type': 'settings'}),
                icon: const Icon(Icons.settings_outlined, size: 19),
                label: const Text('设置'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)))),
      ])
    ]);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final landscape = box.maxWidth > box.maxHeight && box.maxWidth > 600;
        const backdrop = Image(
            image: homeBackgroundImage,
            fit: BoxFit.cover,
            alignment: Alignment(0, -.6),
            excludeFromSemantics: true);
        if (landscape) {
          return Row(children: [
            const Expanded(child: Stack(fit: StackFit.expand, children: [backdrop])),
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Center(
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                          Text('魔塔', style: display(40)),
                          const SizedBox(height: 24),
                          actions()
                        ])))))
          ]);
        }
        return Stack(children: [
          const Positioned.fill(child: backdrop),
          const Positioned.fill(
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [.55, 1],
                          colors: [Colors.transparent, Color(0xe6161b22)])))),
          Positioned(
              top: 8,
              left: 8,
              child: Semantics(
                  label: '魔塔',
                  header: true,
                  child: const SizedBox(width: 1, height: 1))),
          Positioned(bottom: 18, left: 36, right: 36, child: actions()),
        ]);
      });
}
