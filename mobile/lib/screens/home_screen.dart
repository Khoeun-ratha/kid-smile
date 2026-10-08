import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/pack_repository.dart';
import '../models/category.dart';
import '../services/app_language.dart';
import '../services/content_sync.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/responsive.dart';
import 'quiz_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = PackRepository();
  late Future<List<QuizCategory>> _categoriesFuture;
  AppLang? _loadedForLang;
  int? _loadedVersion;

  Future<void> _startQuiz(
    BuildContext context, {
    int? categoryId,
    required String title,
    required String icon,
    required Color color,
  }) async {
    // Centered pop-up that bounces in; tapping outside or ✕ cancels.
    final count = await showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (_, _, _) =>
          _LengthPicker(title: title, icon: icon, color: color),
      transitionBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 0.8, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      ),
    );
    if (count == null || !context.mounted) return;
    Navigator.of(context).push(
      kidRoute(
        QuizScreen(
          categoryId: categoryId,
          categoryTitle: title,
          questionCount: count,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppLanguage>();
    // English and Khmer are independent content sets, so switching the
    // language re-queries local SQLite for that language's categories
    // rather than re-labeling the same rows.
    // Also re-queried when a background sync brought in new content.
    final contentSync = context.watch<ContentSync>();
    if (_loadedForLang != lang.lang ||
        _loadedVersion != contentSync.contentVersion) {
      _loadedForLang = lang.lang;
      _loadedVersion = contentSync.contentVersion;
      _categoriesFuture = _repository.getCategories(lang.lang.name);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kid Smile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () =>
                Navigator.of(context).push(kidRoute(const SettingsScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          // Reassures parents and kids that no connection is fine.
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: contentSync.online
                ? const SizedBox(width: double.infinity)
                : _OfflineBadge(text: t('offline_badge', lang.lang)),
          ),
          Expanded(
            child: FutureBuilder<List<QuizCategory>>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final categories = snapshot.data!;
                final mixedQuizTitle = t('mixed_quiz', lang.lang);

                if (categories.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: KidPanel(
                        child: Text(
                          t('no_categories_yet', lang.lang),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                  );
                }

                final List<({String icon, String name, Color color, int? id})>
                tiles = [
                  (
                    icon: '🎲',
                    name: mixedQuizTitle,
                    color: AppTheme.primary,
                    id: null,
                  ),
                  for (final c in categories)
                    (
                      icon: c.icon,
                      name: c.name,
                      color: AppTheme.fromHex(c.color),
                      id: c.id,
                    ),
                ];

                final short = context.isShortScreen;
                // Capped so tiles stay a sensible size on big desktop windows.
                return MaxWidth(
                  maxWidth: 1100,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // 2 columns on phones, more on tablets / desktop browsers so
                      // the tiles don't blow up to giant squares.
                      final columns = (constraints.maxWidth / 200)
                          .floor()
                          .clamp(2, 6);
                      final spacing = constraints.maxWidth < 360 ? 12.0 : 16.0;
                      return GridView.builder(
                        // Keyed on language so switching re-plays the entrance.
                        key: ValueKey(lang.lang),
                        padding: EdgeInsets.all(spacing),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: spacing,
                          crossAxisSpacing: spacing,
                          // Sideways phones: wider-than-tall tiles so a whole row
                          // fits on screen.
                          childAspectRatio: short ? 1.35 : 1,
                        ),
                        itemCount: tiles.length,
                        itemBuilder: (context, i) {
                          final tile = tiles[i];
                          return FadeSlideIn(
                            delay: Duration(milliseconds: 70 * i),
                            child: _CategoryTile(
                              icon: tile.icon,
                              name: tile.name,
                              color: tile.color,
                              onTap: () => _startQuiz(
                                context,
                                categoryId: tile.id,
                                title: tile.name,
                                icon: tile.icon,
                                color: tile.color,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Small pill shown at the top of the home screen while offline.
class _OfflineBadge extends StatelessWidget {
  final String text;

  const _OfflineBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    final color = Colors.orange.shade800;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: color, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String icon;
  final String name;
  final Color color;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.icon,
    required this.name,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Bouncy(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(color, Colors.white, 0.15)!, color],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        // Emoji and label scale with the tile, so they look right from a
        // small phone up to a desktop window.
        child: LayoutBuilder(
          builder: (context, box) {
            final side = box.biggest.shortestSide;
            final emojiSize = (side * 0.36).clamp(28.0, 84.0);
            final labelSize = (box.maxWidth * 0.11).clamp(14.0, 26.0);
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Wiggle(
                  // Slightly different tempo per tile so they don't bob in
                  // lockstep.
                  period: Duration(
                    milliseconds: 1600 + name.hashCode.abs() % 6 * 150,
                  ),
                  child: Text(icon, style: TextStyle(fontSize: emojiSize)),
                ),
                SizedBox(height: side * 0.05),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: labelSize,
                      height: 1.15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Centered dialog asking how long the quiz should be.
class _LengthPicker extends StatelessWidget {
  final String title;
  final String icon;
  final Color color;

  const _LengthPicker({
    required this.title,
    required this.icon,
    required this.color,
  });

  static const _emoji = {6: '🐣', 8: '🐥', 10: '🐔'};

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppLanguage>().lang;
    final textTheme = Theme.of(context).textTheme;
    // Scrolls if a sideways phone is too short to show it all.
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              elevation: 12,
              shadowColor: Colors.black38,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(icon, style: const TextStyle(fontSize: 48)),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.brown.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t('how_many_questions', lang),
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge?.copyWith(
                            color: Colors.brown.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            for (final n in QuizScreen.lengthOptions) ...[
                              if (n != QuizScreen.lengthOptions.first)
                                const SizedBox(width: 12),
                              Expanded(
                                child: FadeSlideIn(
                                  delay: Duration(milliseconds: 60 * n),
                                  child: Bouncy(
                                    onTap: () => Navigator.of(context).pop(n),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color.lerp(
                                              color,
                                              Colors.white,
                                              0.25,
                                            )!,
                                            color,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(22),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color.lerp(
                                              color,
                                              Colors.black,
                                              0.22,
                                            )!,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            _emoji[n] ?? '⭐',
                                            style: const TextStyle(
                                              fontSize: 30,
                                            ),
                                          ),
                                          Text(
                                            localizedNumber(n, lang),
                                            style: textTheme.headlineMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                          ),
                                          Text(
                                            t('questions_word', lang),
                                            style: textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.brown.shade400,
                        size: 28,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
