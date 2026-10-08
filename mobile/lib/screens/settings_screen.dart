import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/pack_repository.dart';
import '../services/app_language.dart';
import '../services/content_sync.dart';
import '../services/sync_service.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/kid_button.dart';
import '../widgets/responsive.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _sky = Color(0xFF3FA9F5);

  final _repository = PackRepository();
  bool _checking = false;
  SyncStatus? _status;

  AppLang? _countsLang;
  int? _countsVersion;
  late Future<({int categories, int questions})> _counts;
  late final Future<
    ({int games, int bestPercent, int averagePercent, int perfect})
  >
  _stats = _repository.getPlayStats();

  void _reloadCounts(AppLang lang, int contentVersion) {
    _countsLang = lang;
    _countsVersion = contentVersion;
    _counts = _repository.getContentCounts(lang.name);
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _checking = true;
      _status = null;
    });
    final lang = context.read<AppLanguage>().lang;
    final status = await context.read<ContentSync>().syncLanguage(lang.name);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _status = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appLanguage = context.watch<AppLanguage>();
    final lang = appLanguage.lang;
    // Reload counts on a language switch, and whenever any sync (manual or
    // automatic) brought in new questions.
    final contentVersion = context.watch<ContentSync>().contentVersion;
    if (_countsLang != lang) {
      _reloadCounts(lang, contentVersion);
      _status = null; // a status about the other language is now stale
    } else if (_countsVersion != contentVersion) {
      _reloadCounts(lang, contentVersion);
    }
    final textTheme = Theme.of(context).textTheme;
    final hintStyle = textTheme.bodyLarge?.copyWith(
      color: Colors.brown.shade600,
    );

    return Scaffold(
      appBar: AppBar(title: Text(t('settings', lang))),
      body: MaxWidth(
        maxWidth: context.isLargeScreen ? 680 : 560,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            FadeSlideIn(
              child: _Section(
                emoji: '🌏',
                title: t('language', lang),
                children: [
                  Text(t('settings_language_hint', lang), style: hintStyle),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final option in AppLang.values) ...[
                        if (option != AppLang.values.first)
                          const SizedBox(width: 12),
                        Expanded(
                          child: _LanguageCard(
                            flag: option == AppLang.en ? '🇬🇧' : '🇰🇭',
                            label: option == AppLang.en ? 'English' : 'ខ្មែរ',
                            selected: option == lang,
                            onTap: () => appLanguage.setLang(option),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: _Section(
                emoji: '📚',
                title: t('content_section', lang),
                children: [
                  FutureBuilder(
                    future: _counts,
                    builder: (context, snapshot) {
                      final counts = snapshot.data;
                      return Text(
                        counts == null
                            ? ' '
                            : t('content_summary', lang)
                                  .replaceAll(
                                    '{categories}',
                                    '${counts.categories}',
                                  )
                                  .replaceAll(
                                    '{questions}',
                                    '${counts.questions}',
                                  ),
                        style: hintStyle,
                      );
                    },
                  ),
                  // Offline-only builds have no server to check.
                  if (context.read<ContentSync>().enabled) ...[
                    const SizedBox(height: 14),
                    KidButton(
                      icon: Icons.cloud_download_rounded,
                      label: t('check_for_new_questions', lang),
                      color: _sky,
                      loading: _checking,
                      onTap: _checkForUpdates,
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _status == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: _StatusBanner(
                                status: _status!,
                                lang: lang,
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: _Section(
                emoji: '🏆',
                title: t('my_progress', lang),
                children: [
                  FutureBuilder(
                    future: _stats,
                    builder: (context, snapshot) {
                      final stats = snapshot.data;
                      if (stats == null) return const SizedBox(height: 80);
                      if (stats.games == 0) {
                        return Text(t('no_games_yet', lang), style: hintStyle);
                      }
                      final tiles = [
                        _StatTile(
                          emoji: '🎮',
                          value: '${stats.games}',
                          label: t('games_played', lang),
                          color: _sky,
                        ),
                        _StatTile(
                          emoji: '⭐',
                          value: '${stats.bestPercent}%',
                          label: t('best_score', lang),
                          color: Colors.amber.shade800,
                        ),
                        _StatTile(
                          emoji: '📈',
                          value: '${stats.averagePercent}%',
                          label: t('average_score', lang),
                          color: AppTheme.correct,
                        ),
                        _StatTile(
                          emoji: '💯',
                          value: '${stats.perfect}',
                          label: t('perfect_games', lang),
                          color: AppTheme.primary,
                        ),
                      ];
                      // Natural-height tiles (no fixed aspect ratio), so
                      // long Khmer labels or big system text never clip:
                      // four across when there's room, else two.
                      return LayoutBuilder(
                        builder: (context, box) {
                          final columns = box.maxWidth >= 520 ? 4 : 2;
                          const gap = 10.0;
                          final width =
                              (box.maxWidth - gap * (columns - 1)) / columns;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final tile in tiles)
                                SizedBox(width: width, child: tile),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              t('app_footer', lang),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.brown.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled frosted card grouping one area of settings.
class _Section extends StatelessWidget {
  final String emoji;
  final String title;
  final List<Widget> children;

  const _Section({
    required this.emoji,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return KidPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.brown.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

/// Big flag card for picking the play language; the chosen one fills with
/// color and pops a check badge.
class _LanguageCard extends StatelessWidget {
  final String flag;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.flag,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const color = AppTheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Bouncy(
        onTap: selected ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? color : Colors.brown.shade100,
              width: selected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? color.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: selected ? 14 : 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Text(flag, style: const TextStyle(fontSize: 40)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: selected ? color : Colors.brown.shade700,
                    ),
                  ),
                ],
              ),
              Positioned(
                top: -6,
                right: 0,
                child: AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutBack,
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: color,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Colored result line for the last "check for new questions" tap.
class _StatusBanner extends StatelessWidget {
  final SyncStatus status;
  final AppLang lang;

  const _StatusBanner({required this.status, required this.lang});

  @override
  Widget build(BuildContext context) {
    final (emoji, color, key) = switch (status) {
      SyncStatus.updated => ('🎉', AppTheme.correct, 'updated_msg'),
      SyncStatus.upToDate => ('👍', const Color(0xFF3FA9F5), 'up_to_date_msg'),
      SyncStatus.offline => ('📴', Colors.orange.shade700, 'offline_msg'),
      SyncStatus.error => ('😕', AppTheme.wrong, 'error_msg'),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t(key, lang),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Color.lerp(color, Colors.black, 0.25),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color color;

  const _StatTile({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.brown.shade700),
          ),
        ],
      ),
    );
  }
}
