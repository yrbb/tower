import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'game/data.dart';
import 'game_controller.dart';
import 'services/audio.dart';
import 'services/storage.dart';
import 'ui/title_screen.dart' show homeBackgroundImage;

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Keep the native splash until the home artwork can be painted in the first frame.
  binding.deferFirstFrame();
  final background = homeBackgroundImage.resolve(ImageConfiguration.empty);
  final backgroundReady = Completer<void>();
  void ready() {
    if (!backgroundReady.isCompleted) backgroundReady.complete();
  }

  final listener = ImageStreamListener((image, _) {
    image.dispose();
    ready();
  }, onError: (_, __) => ready());
  background.addListener(listener);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0xff161b22),
      systemNavigationBarColor: Color(0xff161b22),
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light));
  final data =
      GameData.fromJson(await rootBundle.loadString('assets/data/game.json'));
  final storage = SaveStore(await createBackend());
  await storage.init();
  final audio = NativeAudio(
      jsonDecode(await rootBundle.loadString('assets/data/audio.json')));
  runApp(StarTowerApp(GameController(data, storage, audio)));
  await backgroundReady.future;
  binding.allowFirstFrame();
  await binding.endOfFrame;
  background.removeListener(listener);
  unawaited(audio.prepareEffects());
}
