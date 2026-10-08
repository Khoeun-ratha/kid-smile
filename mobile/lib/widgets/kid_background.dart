import 'dart:math' as math;

import 'package:flutter/material.dart';

/// App-wide playful backdrop: a sky-to-sunset gradient with drifting clouds,
/// rolling hills, pastel bubbles floating upward and twinkling stars.
///
/// Built for cheapness, since it runs behind every screen:
/// - one [AnimationController] for the whole app (mounted once in
///   `MaterialApp.builder`, so it survives navigation instead of restarting),
/// - the painter listens to the controller directly, so ticks repaint only
///   the canvas — no widget rebuilds,
/// - wrapped in a [RepaintBoundary] so the background and the screens on top
///   never force each other to repaint,
/// - static when the OS "reduce motion" setting is on.
class KidBackground extends StatefulWidget {
  final Widget child;

  const KidBackground({super.key, required this.child});

  @override
  State<KidBackground> createState() => _KidBackgroundState();
}

class _KidBackgroundState extends State<KidBackground>
    with SingleTickerProviderStateMixin {
  /// One full loop; every motion below completes a whole number of cycles
  /// per loop, so the repeat is seamless.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(painter: _BackgroundPainter(_controller)),
        ),
        widget.child,
      ],
    );
  }
}

class _Bubble {
  final double x; // 0..1 across the width
  final double y; // 0..1 starting height
  final double radius; // fraction of the shortest side
  final int rises; // full trips up the screen per loop
  final double swayPhase;
  final Color color;

  const _Bubble(
    this.x,
    this.y,
    this.radius,
    this.rises,
    this.swayPhase,
    this.color,
  );
}

class _Star {
  final double x;
  final double y;
  final double size;
  final double phase;

  const _Star(this.x, this.y, this.size, this.phase);
}

class _Cloud {
  final double x; // 0..1 starting position across the width
  final double y; // 0..1 height of the cloud's top edge
  final double scale; // width as a fraction of the shortest side
  final int laps; // full trips across the screen per loop

  const _Cloud(this.x, this.y, this.scale, this.laps);
}

class _BackgroundPainter extends CustomPainter {
  final Animation<double> animation;

  _BackgroundPainter(this.animation) : super(repaint: animation);

  static const _palette = [
    Color(0xFFFFB3A7), // peach
    Color(0xFFFFE08A), // sunny
    Color(0xFFA8E6CF), // mint
    Color(0xFFA7D8FF), // sky
    Color(0xFFD7B8F3), // lilac
  ];

  // Fixed seed: the same layout every launch, generated once.
  static final List<_Bubble> _bubbles = () {
    final r = math.Random(7);
    return List.generate(14, (i) {
      return _Bubble(
        r.nextDouble(),
        r.nextDouble(),
        0.04 + r.nextDouble() * 0.09,
        1 + r.nextInt(2),
        r.nextDouble() * 2 * math.pi,
        _palette[i % _palette.length],
      );
    });
  }();

  static final List<_Star> _stars = () {
    final r = math.Random(11);
    return List.generate(10, (_) {
      return _Star(
        r.nextDouble(),
        r.nextDouble(),
        5 + r.nextDouble() * 6,
        r.nextDouble(),
      );
    });
  }();

  static const _clouds = [
    _Cloud(0.05, 0.05, 0.42, 1),
    _Cloud(0.55, 0.13, 0.32, 1),
    _Cloud(0.80, 0.30, 0.26, 2),
  ];

  final Paint _gradientPaint = Paint();
  Size? _gradientSize;

  static final Paint _bubblePaint = Paint();
  static final Paint _cloudPaint = Paint();
  static final Paint _hillPaint = Paint();
  static final Paint _starPaint = Paint()..color = const Color(0xFFFFC94D);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Shader only rebuilt when the screen size changes, not every frame.
    if (size != _gradientSize) {
      _gradientSize = size;
      _gradientPaint.shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        // Sky blue at the top melting into warm cream and a soft pink
        // floor: clearly colorful, but light enough for dark text on top.
        colors: [Color(0xFFB8E2FF), Color(0xFFFFF3DC), Color(0xFFFFD3DF)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(rect);
    }
    canvas.drawRect(rect, _gradientPaint);

    final t = animation.value;
    final shortest = size.shortestSide;

    // Fluffy clouds drifting slowly across the sky band.
    for (final c in _clouds) {
      final w = c.scale * shortest;
      final travel = size.width + 2 * w;
      final dx = (c.x + t * c.laps) % 1.0 * travel - w;
      _drawCloud(canvas, Offset(dx, c.y * size.height), w);
    }

    // Rolling hills along the bottom edge give the scene a "ground".
    _drawHill(canvas, size, 0.86, 0.10, 0.4, const Color(0xFFB9EBC9));
    _drawHill(canvas, size, 0.92, 0.07, 1.9, const Color(0xFF9EDFB4));

    for (final b in _bubbles) {
      final r = b.radius * shortest;
      // Rise from below the bottom edge to above the top edge, then wrap.
      final travel = size.height + 2 * r;
      final progress = (b.y + t * b.rises) % 1.0;
      final dy = size.height + r - progress * travel;
      final dx =
          b.x * size.width +
          math.sin(t * 2 * math.pi * 3 + b.swayPhase) * r * 0.6;
      _bubblePaint.color = b.color.withValues(alpha: 0.5);
      canvas.drawCircle(Offset(dx, dy), r, _bubblePaint);
      // Little highlight so they read as bubbles, not blobs.
      _bubblePaint.color = Colors.white.withValues(alpha: 0.6);
      canvas.drawCircle(
        Offset(dx - r * 0.35, dy - r * 0.35),
        r * 0.22,
        _bubblePaint,
      );
    }

    for (final s in _stars) {
      final twinkle = 0.5 + 0.5 * math.sin((t * 8 + s.phase) * 2 * math.pi);
      _starPaint.color = const Color(
        0xFFFFC94D,
      ).withValues(alpha: 0.35 + 0.55 * twinkle);
      _drawStar(
        canvas,
        Offset(s.x * size.width, s.y * size.height),
        s.size * (0.8 + 0.3 * twinkle),
      );
    }
  }

  void _drawCloud(Canvas canvas, Offset origin, double w) {
    _cloudPaint.color = Colors.white.withValues(alpha: 0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx, origin.dy, w, w * 0.32),
        Radius.circular(w * 0.16),
      ),
      _cloudPaint,
    );
    canvas.drawCircle(
      origin + Offset(w * 0.34, w * 0.04),
      w * 0.2,
      _cloudPaint,
    );
    canvas.drawCircle(
      origin + Offset(w * 0.62, w * 0.02),
      w * 0.26,
      _cloudPaint,
    );
  }

  void _drawHill(
    Canvas canvas,
    Size size,
    double top,
    double height,
    double phase,
    Color color,
  ) {
    final baseY = size.height * top;
    final amp = size.height * height * 0.5;
    final path = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width; x += 8) {
      final y =
          baseY + amp * math.sin(x / size.width * 2 * math.pi * 1.2 + phase);
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    _hillPaint.color = color.withValues(alpha: 0.75);
    canvas.drawPath(path, _hillPaint);
  }

  void _drawStar(Canvas canvas, Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final r = i.isEven ? radius : radius * 0.45;
      final p = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), _starPaint);
  }

  @override
  bool shouldRepaint(_BackgroundPainter oldDelegate) =>
      oldDelegate.animation != animation;
}
