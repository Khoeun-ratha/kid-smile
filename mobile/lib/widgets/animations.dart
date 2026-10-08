import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared kid-friendly motion building blocks used across screens.

/// Page route that pops the next screen in with a fade + slight zoom,
/// instead of the platform's default slide.
///
/// Scaffolds are transparent (the shared [KidBackground] shows through), so
/// the outgoing screen also fades out via `secondaryAnimation` — otherwise
/// both screens' content would overlap on top of the backdrop mid-transition.
Route<T> kidRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 450),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: FadeTransition(
          opacity: ReverseAnimation(
            CurvedAnimation(
              parent: secondaryAnimation,
              curve: const Interval(0, 0.5, curve: Curves.easeOut),
            ),
          ),
          child: ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Fades and slides [child] up into place once, after [delay]. Give a list of
/// these increasing delays for a staggered entrance.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset from;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
    this.from = const Offset(0, 0.25),
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween(begin: widget.from, end: Offset.zero).animate(curved),
        child: widget.child,
      ),
    );
  }
}

/// Squishes down while pressed and springs back on release — makes any
/// tappable feel like a physical toy button.
class Bouncy extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const Bouncy({super.key, required this.child, this.onTap});

  @override
  State<Bouncy> createState() => _BouncyState();
}

class _BouncyState extends State<Bouncy> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: Duration(milliseconds: _pressed ? 90 : 350),
          curve: _pressed ? Curves.easeOut : Curves.elasticOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Gently bobs/tilts its child forever — used for emoji so screens feel alive.
class Wiggle extends StatefulWidget {
  final Widget child;
  final Duration period;
  final double angle;
  final double lift;

  const Wiggle({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 1800),
    this.angle = 0.08,
    this.lift = 6,
  });

  @override
  State<Wiggle> createState() => _WiggleState();
}

class _WiggleState extends State<Wiggle> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      // Rasterize the emoji once; each tick then only moves the cached layer.
      child: RepaintBoundary(child: widget.child),
      builder: (_, child) {
        final t = _controller.value * 2 * math.pi;
        return Transform.translate(
          offset: Offset(0, -widget.lift * math.sin(t).abs()),
          child: Transform.rotate(
            angle: widget.angle * math.sin(t),
            child: child,
          ),
        );
      },
    );
  }
}

/// Shakes its child side to side each time [trigger] changes to true —
/// the classic "nope, wrong answer" wobble.
class Shake extends StatefulWidget {
  final Widget child;
  final bool trigger;

  const Shake({super.key, required this.child, required this.trigger});

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void didUpdateWidget(Shake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (_, child) {
        final v = _controller.value;
        final dx = math.sin(v * math.pi * 6) * 10 * (1 - v);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}

/// Pops its child with an overshooting scale each time [trigger] turns true.
class Pop extends StatefulWidget {
  final Widget child;
  final bool trigger;

  const Pop({super.key, required this.child, required this.trigger});

  @override
  State<Pop> createState() => _PopState();
}

class _PopState extends State<Pop> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void didUpdateWidget(Pop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (_, child) {
        final scale = 1 + 0.08 * math.sin(_controller.value * math.pi);
        return Transform.scale(scale: scale, child: child);
      },
    );
  }
}

/// Keeps content a readable width on desktop/web while staying full-width
/// on phones.
class MaxWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const MaxWidth({super.key, required this.child, this.maxWidth = 560});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Frosted white card that keeps text crisp on top of the colorful
/// [KidBackground].
class KidPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const KidPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
