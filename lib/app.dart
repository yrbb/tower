import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_controller.dart';
import 'ui/ending_fx.dart';
import 'ui/game_screen.dart';
import 'ui/modals.dart';
import 'ui/theme.dart';
import 'ui/title_screen.dart';

class StarTowerApp extends StatefulWidget {
  const StarTowerApp(this.controller, {super.key});
  final GameController controller;
  @override
  State<StarTowerApp> createState() => _StarTowerAppState();
}

class _StarTowerAppState extends State<StarTowerApp>
    with WidgetsBindingObserver {
  GameController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      c.audio.suspend(state != AppLifecycleState.resumed);
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.dispose();
    super.dispose();
  }

  void back() {
    if (c.modal != null) {
      if (!['story', 'ending'].contains(c.modal?['type'])) c.closeModal();
    } else if (c.screen == 'playing') {
      c.openModal({'type': 'pause'});
    }
  }

  Widget stage() => Stack(children: [
        Positioned.fill(
            child: ExcludeSemantics(
                excluding: c.modal != null,
                child: c.screen == 'title' ? TitleScreen(c) : GameScreen(c))),
        if (c.transition != null)
          Positioned.fill(
              child: IgnorePointer(
                  child: Center(
                      child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: panel(color: bg.withOpacity(.95)),
            child: Text(c.transition!['title'],
                textAlign: TextAlign.center, style: display(22)),
          )))),
        if (c.toasts.isNotEmpty)
          Positioned(
              left: 20,
              right: 20,
              top: 8,
              child: IgnorePointer(
                  child: Semantics(
                liveRegion: true,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: panel(
                      border: c.toasts.last['tone'] == 'warn' ? danger : gold,
                      color: const Color(0xf220272c)),
                  child: Text(c.toasts.last['text'],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14,
                          color:
                              c.toasts.last['tone'] == 'warn' ? danger : ink)),
                ),
              ))),
        if (c.modal != null) Positioned.fill(child: GameModals(c)),
        if (c.modal?['type'] == 'ending')
          const Positioned.fill(child: EndingFx()),
      ]);
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '魔塔',
        theme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: false,
            scaffoldBackgroundColor: bg,
            colorScheme: const ColorScheme.dark(
                primary: gold, secondary: goldSoft, surface: Color(0xff20272c)),
            textTheme: ThemeData.dark()
                .textTheme
                .apply(bodyColor: ink, displayColor: ink),
            textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                    foregroundColor: goldSoft,
                    minimumSize: const Size(48, 48))),
            iconButtonTheme: IconButtonThemeData(
                style: IconButton.styleFrom(minimumSize: const Size(48, 48)))),
        home: AnimatedBuilder(
            animation: c,
            builder: (context, _) {
              return PopScope(
                canPop: c.screen == 'title' && c.modal == null,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) back();
                },
                child: Scaffold(
                    body: Listener(
                        onPointerDown: (_) => c.titleMusic(),
                        child: SafeArea(
                          child: LayoutBuilder(
                              builder: (context, box) => Center(
                                      child: SizedBox(
                                    width: math.min(1000, box.maxWidth),
                                    height: box.maxHeight,
                                    child: stage(),
                                  ))),
                        ))),
              );
            }),
      );
}
