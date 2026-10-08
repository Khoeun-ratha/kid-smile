import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/pack_repository.dart';
import '../services/app_language.dart';
import '../services/content_sync.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// Drives the logo's bouncy drop-in; startup work runs in parallel and we
  /// wait for both so the intro is never cut off mid-bounce.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _intro.forward();
    _prepare();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    // Make sure the persisted language choice is loaded before anything
    // below reads it — main.dart kicks this off but doesn't block on it.
    final appLanguage = context.read<AppLanguage>();
    await appLanguage.load();

    final repository = PackRepository();
    // Guarantees the app is playable offline before we ever touch the
    // network: seed import always finishes first. Both English and Khmer
    // ship a bundled starter pack, so either language works on a fresh
    // install.
    await Future.wait([
      repository.ensureSeeded(),
      _intro.forward().orCancel.catchError((_) {}),
    ]);

    // Best-effort: from here on, newer content is fetched in the background
    // now and whenever the connection comes back — never blocking play.
    if (!mounted) return;
    unawaited(context.read<ContentSync>().start());

    if (!mounted) return;
    Navigator.of(context).pushReplacement(kidRoute(const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final logoScale = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0, 0.7, curve: Curves.elasticOut),
    );
    final textFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.35, 1, curve: Curves.easeOut),
    );
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: logoScale,
              child: const Wiggle(
                child: Text('😄', style: TextStyle(fontSize: 72)),
              ),
            ),
            const SizedBox(height: 16),
            FadeTransition(
              opacity: textFade,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.5),
                  end: Offset.zero,
                ).animate(textFade),
                child: const Text(
                  'Kid Smile',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
