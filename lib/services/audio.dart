import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../game/data.dart';

abstract class GameAudio {
  void effect(String name);
  void music(int floor);
  void stopMusic();
  void setVolume(double volume);
  void setMuted(bool muted);
  void suspend(bool suspended);
  void dispose();
}

class SilentAudio implements GameAudio {
  @override
  void effect(String name) {}
  @override
  void music(int floor) {}
  @override
  void stopMusic() {}
  @override
  void setVolume(double volume) {}
  @override
  void setMuted(bool muted) {}
  @override
  void suspend(bool suspended) {}
  @override
  void dispose() {}
}

class _ClipPool {
  _ClipPool(this.key, this.duration);
  final Duration duration;
  final bool lowLatency =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final timers = <AudioPlayer, Timer>{};
  final String key;
  final players = <AudioPlayer>[];
  final busy = <AudioPlayer>{};
  bool disposed = false;
  Future<AudioPlayer> create() async {
    final p = AudioPlayer();
    try {
      // Short overlapping game clips must not use Android's MediaPlayer completion/re-prepare path.
      if (lowLatency) {
        // Each note must not steal audio focus from other notes in the same game.
        await p.setAudioContext(AudioContext(
            android: const AudioContextAndroid(
          audioFocus: AndroidAudioFocus.none,
          usageType: AndroidUsageType.game,
        )));
        await p.setPlayerMode(PlayerMode.lowLatency);
      }
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setSource(AssetSource('audio/$key.wav'));
      if (disposed) {
        await p.dispose();
        throw StateError('Disposed');
      }
      players.add(p);
      if (!lowLatency) {
        p.onPlayerComplete.listen((_) {
          busy.remove(p);
        });
      }
      return p;
    } catch (_) {
      await p.dispose();
      rethrow;
    }
  }

  Future<void> play(double volume) async {
    if (disposed) return;
    AudioPlayer? p;
    for (final candidate in players) {
      if (!busy.contains(candidate)) {
        p = candidate;
        break;
      }
    }
    p ??= await create();
    if (disposed) return;
    busy.add(p);
    try {
      if (lowLatency) await p.stop();
      await p.setVolume(volume);
      await p.resume();
      if (lowLatency) {
        final player = p;
        // SoundPool has no completion event; WAV duration bounds pool reuse.
        timers[player] = Timer(duration, () {
          timers.remove(player);
          busy.remove(player);
        });
      }
    } catch (_) {
      busy.remove(p);
    }
  }

  Future<void> volume(double v) async {
    for (final p in players.toList()) {
      try {
        await p.setVolume(v);
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    disposed = true;
    for (final timer in timers.values) {
      timer.cancel();
    }
    timers.clear();
    for (final p in players.toList()) {
      await p.dispose();
    }
    players.clear();
    busy.clear();
  }
}

// shortcut: pre-rendered clips preserve synthesis parameters, not shared live WebAudio compression; use native DSP if sample parity is required.
class NativeAudio implements GameAudio {
  NativeAudio(this.manifest);
  final Obj manifest;
  final _pools = <String, Future<_ClipPool>>{};
  final _retireTimers = <Timer>{};
  Timer? _timer;
  int? _floor;
  int _step = 0;
  bool _muted = false, _suspended = false, _disposed = false;
  double _volume = .9;
  double get outputVolume => _muted || _suspended ? 0 : _volume;
  Future<_ClipPool> _pool(String key) => _pools.putIfAbsent(key, () async {
        final wav = await rootBundle.load('assets/audio/$key.wav');
        final duration = Duration(
            microseconds: (wav.getUint32(40, Endian.little) *
                    1000000 /
                    wav.getUint32(28, Endian.little))
                .ceil());
        final p = _ClipPool(key, duration);
        await p.create();
        if (_disposed) await p.dispose();
        return p;
      });
  Future<void> prepareEffects() async {
    for (final name in manifest['effects']) {
      if (_disposed) break;
      try {
        await _pool('sfx-$name');
      } catch (_) {}
    }
  }

  Future<void> _play(String key) async {
    try {
      final p = await _pool(key);
      if (!_disposed) await p.play(outputVolume);
    } catch (_) {/* Audio failure never changes the game state. */}
  }

  @override
  void effect(String name) {
    if (!_disposed) unawaited(_play('sfx-$name'));
  }

  @override
  void music(int floor) {
    if (_disposed || (_floor == floor && _timer != null)) return;
    stopMusic();
    _floor = floor;
    _step = 0;
    for (var i = 0; i < 8; i++) {
      _pool('bgm-$floor-$i').ignore();
    }
    _timer = Timer.periodic(
        Duration(milliseconds: manifest['tracks']['$floor']['stepMs']), (_) {
      if (_muted || _suspended || _disposed) return;
      unawaited(_play('bgm-$floor-${_step % 8}'));
      _step++;
    });
  }

  @override
  void stopMusic() {
    final previous = _floor;
    _timer?.cancel();
    _timer = null;
    _floor = null;
    if (previous == null) return;
    // Let already sounding notes decay, then release the previous floor's players.
    late Timer retire;
    retire = Timer(const Duration(milliseconds: 1200), () {
      _retireTimers.remove(retire);
      if (_floor == previous) return;
      for (var i = 0; i < 8; i++) {
        final p = _pools.remove('bgm-$previous-$i');
        if (p != null) unawaited(p.then((p) => p.dispose()).catchError((_) {}));
      }
    });
    _retireTimers.add(retire);
  }

  Future<void> _volumes() async {
    for (final pending in _pools.values.toList()) {
      try {
        await (await pending).volume(outputVolume);
      } catch (_) {}
    }
  }

  @override
  void setVolume(double v) {
    _volume = v.clamp(0, 1);
    unawaited(_volumes());
  }

  @override
  void setMuted(bool muted) {
    _muted = muted;
    unawaited(_volumes());
  }

  @override
  void suspend(bool suspended) {
    _suspended = suspended;
    unawaited(_volumes());
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    for (final t in _retireTimers) {
      t.cancel();
    }
    _retireTimers.clear();
    for (final p in _pools.values) {
      unawaited(p.then((p) => p.dispose()).catchError((_) {}));
    }
    _pools.clear();
  }
}
