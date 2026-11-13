import 'dart:async';

class HoldRepeat {
  HoldRepeat(this.step);
  final bool Function() step;
  Timer? _timeout, _timer;
  void stop() {
    _timeout?.cancel();
    _timer?.cancel();
    _timeout = null;
    _timer = null;
  }

  void start() {
    stop();
    if (!step()) return;
    _timeout = Timer(const Duration(milliseconds: 230), () {
      _timer = Timer.periodic(const Duration(milliseconds: 140), (_) {
        if (!step()) stop();
      });
    });
  }

  bool get active => _timeout != null || _timer != null;
}
