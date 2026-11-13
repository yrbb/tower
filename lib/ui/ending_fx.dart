import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'theme.dart';

class EndingFx extends StatefulWidget {
  const EndingFx({super.key});
  @override
  State<EndingFx> createState() => _EndingFxState();
}

class _Particle {
  _Particle(this.x, this.y, this.vx, this.vy, this.decay, this.size, this.color,
      this.trail);
  double x, y, vx, vy, life = 1;
  final double decay, size;
  final Color color;
  final bool trail;
}

class _EndingFxState extends State<EndingFx>
    with SingleTickerProviderStateMixin {
  final random = math.Random();
  final particles = <_Particle>[];
  static const palette = [
    Color(0xffffe58a),
    gold,
    Color(0xfffff6c8),
    Color(0xffffb347),
    Color(0xffff8a5c),
    Color(0xff9bffb8)
  ];
  late final Ticker ticker = createTicker(frame);
  Size size = Size.zero;
  double ms = 0, lastBurst = 0, lastSpark = 0;
  bool started = false, reduced = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) {
      ticker.stop();
    } else if (!ticker.isActive) {
      ticker.start();
    }
  }

  void burst(double x, double y, int n) {
    for (var i = 0; i < n; i++) {
      final angle = random.nextDouble() * math.pi * 2,
          speed = 1.6 + random.nextDouble() * 4.8;
      particles.add(_Particle(
          x,
          y,
          math.cos(angle) * speed,
          math.sin(angle) * speed,
          .011 + random.nextDouble() * .012,
          1.4 + random.nextDouble() * 2.6,
          palette[random.nextInt(palette.length)],
          random.nextDouble() < .35));
    }
  }

  void frame(Duration elapsed) {
    ms = elapsed.inMicroseconds / 1000;
    if (size == Size.zero) return;
    if (!started) {
      started = true;
      burst(size.width / 2, size.height * .35, 60);
    }
    if (ms < 3500 && ms - lastBurst > (ms < 1500 ? 420 : 680)) {
      lastBurst = ms;
      burst(
          size.width * (.15 + random.nextDouble() * .7),
          size.height * (.12 + random.nextDouble() * .4),
          36 + random.nextInt(26));
    }
    if (ms < 4400 && ms - lastSpark > 90) {
      lastSpark = ms;
      particles.add(_Particle(
          random.nextDouble() * size.width,
          -8,
          (random.nextDouble() - .5) * .8,
          1.2 + random.nextDouble() * 1.6,
          .004 + random.nextDouble() * .004,
          1 + random.nextDouble() * 1.6,
          palette[random.nextInt(palette.length)],
          false));
    }
    particles.removeWhere((p) => p.life <= 0 || p.y >= size.height + 20);
    for (final p in particles) {
      p.vx *= .985;
      p.vy = p.vy * .985 + .045;
      p.x += p.vx;
      p.y += p.vy;
      p.life -= p.decay;
    }
    setState(() {});
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
          child: ExcludeSemantics(child: LayoutBuilder(builder: (_, box) {
        size = box.biggest;
        return RepaintBoundary(
            child: CustomPaint(
                size: size, painter: _EndingPainter(particles, ms, reduced)));
      })));
}

class _EndingPainter extends CustomPainter {
  _EndingPainter(this.particles, this.ms, this.reduced);
  final List<_Particle> particles;
  final double ms;
  final bool reduced;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .34),
        radius = size.width * .9;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(reduced ? 0 : ms / 36000 * math.pi * 2);
    final opacity = reduced ? .12 : .2 * (ms / 1400).clamp(0, 1);
    final paint = Paint()
      ..shader = RadialGradient(
              colors: [gold.withOpacity(opacity), Colors.transparent])
          .createShader(
              Rect.fromCircle(center: Offset.zero, radius: radius * .62));
    for (var i = 0; i < 20; i++) {
      final a = i * math.pi / 10, b = a + math.pi / 30;
      canvas.drawPath(
          Path()
            ..moveTo(0, 0)
            ..lineTo(math.cos(a) * radius, math.sin(a) * radius)
            ..lineTo(math.cos(b) * radius, math.sin(b) * radius)
            ..close(),
          paint);
    }
    canvas.restore();
    if (!reduced && ms < 1100) {
      final t = ms / 1100;
      final alpha = t < .12 ? t / .12 : (1 - t) / .88;
      canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..shader = RadialGradient(colors: [
              const Color(0xfffff6c8).withOpacity(alpha * .85),
              Colors.transparent
            ]).createShader(
                Rect.fromCircle(center: center, radius: size.width * .6)));
    }
    if (!reduced) {
      for (final p in particles) {
        final alpha = p.life.clamp(0.0, 1.0);
        final at = Offset(p.x, p.y), r = p.size * (.6 + alpha * .4);
        canvas.drawCircle(
            at,
            r * 1.5,
            Paint()
              ..color = p.color.withOpacity(alpha * .5)
              ..blendMode = BlendMode.plus
              ..maskFilter =
                  MaskFilter.blur(BlurStyle.normal, p.trail ? 5 : 3));
        canvas.drawCircle(
            at,
            r,
            Paint()
              ..color = p.color.withOpacity(alpha)
              ..blendMode = BlendMode.plus);
      }
    }
  }

  @override
  bool shouldRepaint(_EndingPainter old) => true;
}
