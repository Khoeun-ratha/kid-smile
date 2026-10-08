import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/quiz_engine.dart';
import '../services/app_language.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/kid_button.dart';
import 'home_screen.dart';
import 'quiz_screen.dart';

class ResultScreen extends StatefulWidget {
  final int score;
  final int total;
  final List<AnsweredQuestion> answers;
  final String categoryTitle;
  final int? categoryId;

  /// Length the kid chose, so "Play Again" keeps it.
  final int questionCount;

  const ResultScreen({
    super.key,
    required this.score,
    required this.total,
    this.answers = const [],
    required this.categoryTitle,
    required this.categoryId,
    this.questionCount = 10,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  static const _review = Color(0xFF3FA9F5);

  late final ConfettiController _confetti;
  final _reviewKey = GlobalKey();
  bool _showReview = false;

  bool get _isGreatScore =>
      widget.total > 0 && widget.score / widget.total >= 0.7;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    if (_isGreatScore) _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  int get _stars {
    if (widget.total == 0) return 0;
    final ratio = widget.score / widget.total;
    if (ratio >= 0.9) return 3;
    if (ratio >= 0.6) return 2;
    if (ratio >= 0.3) return 1;
    return 0;
  }

  String get _cheerKey {
    if (widget.total == 0) return 'cheer_low';
    final ratio = widget.score / widget.total;
    if (ratio >= 1) return 'cheer_perfect';
    if (ratio >= 0.7) return 'cheer_great';
    if (ratio >= 0.4) return 'cheer_good';
    return 'cheer_low';
  }

  void _toggleReview() {
    setState(() => _showReview = !_showReview);
    if (!_showReview) return;
    // Once the list has expanded, glide down so the kid sees it open.
    Future.delayed(const Duration(milliseconds: 380), () {
      final target = _reviewKey.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          alignment: 0.1,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppLanguage>().lang;
    final answers = widget.answers;
    final wrong = answers.where((a) => !a.isCorrect && !a.timedOut).length;
    final timedOut = answers.where((a) => a.timedOut).length;

    return Scaffold(
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: KidPanel(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.elasticOut,
                          builder: (_, value, child) =>
                              Transform.scale(scale: value, child: child),
                          child: Wiggle(
                            angle: 0.12,
                            lift: 10,
                            child: Text(
                              _isGreatScore ? '🎉' : '🙂',
                              style: const TextStyle(fontSize: 80),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 200),
                          child: Text(
                            t('you_scored', lang),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        // Score ticks up from 0 like a game scoreboard.
                        TweenAnimationBuilder<int>(
                          tween: IntTween(begin: 0, end: widget.score),
                          duration: Duration(
                            milliseconds: 300 + 120 * widget.score,
                          ),
                          curve: Curves.easeOut,
                          builder: (_, value, _) => Text(
                            '$value / ${widget.total}',
                            style: Theme.of(context).textTheme.displayMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            3,
                            (i) => _Star(filled: i < _stars, index: i),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 1000),
                          child: Text(
                            t(_cheerKey, lang),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.brown.shade700,
                                ),
                          ),
                        ),
                        if (answers.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 1100),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _StatChip(
                                  emoji: '✅',
                                  count: widget.score,
                                  label: t('correct_label', lang),
                                  color: AppTheme.correct,
                                ),
                                _StatChip(
                                  emoji: '❌',
                                  count: wrong,
                                  label: t('wrong_label', lang),
                                  color: AppTheme.wrong,
                                ),
                                if (timedOut > 0)
                                  _StatChip(
                                    emoji: '⏰',
                                    count: timedOut,
                                    label: t('timeout_label', lang),
                                    color: Colors.orange.shade700,
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 1200),
                          child: KidButton(
                            icon: Icons.replay_rounded,
                            label: t('play_again', lang),
                            color: AppTheme.primary,
                            onTap: () {
                              Navigator.of(context).pushReplacement(
                                kidRoute(
                                  QuizScreen(
                                    categoryId: widget.categoryId,
                                    categoryTitle: widget.categoryTitle,
                                    questionCount: widget.questionCount,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (answers.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 1300),
                            child: KidButton(
                              icon: _showReview
                                  ? Icons.expand_less_rounded
                                  : Icons.fact_check_rounded,
                              label: t(
                                _showReview ? 'hide_answers' : 'check_answers',
                                lang,
                              ),
                              color: _review,
                              onTap: _toggleReview,
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: _showReview
                                ? Padding(
                                    key: _reviewKey,
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Column(
                                      children: [
                                        for (var i = 0; i < answers.length; i++)
                                          FadeSlideIn(
                                            delay: Duration(
                                              milliseconds: 60 * i,
                                            ),
                                            from: const Offset(0, 0.3),
                                            child: _ReviewCard(
                                              number: i + 1,
                                              answer: answers[i],
                                              lang: lang,
                                            ),
                                          ),
                                      ],
                                    ),
                                  )
                                : const SizedBox(width: double.infinity),
                          ),
                        ],
                        const SizedBox(height: 14),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 1400),
                          child: KidButton(
                            icon: Icons.home_rounded,
                            label: t('home', lang),
                            color: AppTheme.primary,
                            outlined: true,
                            onTap: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                kidRoute(const HomeScreen()),
                                (route) => false,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          ConfettiWidget(
            confettiController: _confetti,
            blastDirection: 1.57, // downwards
            numberOfParticles: 24,
            maxBlastForce: 20,
            minBlastForce: 8,
            emissionFrequency: 0.05,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String emoji;
  final int count;
  final String label;
  final Color color;

  const _StatChip({
    required this.emoji,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Text(
        '$emoji $count $label',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: color,
        ),
      ),
    );
  }
}

/// One line of the "check my answers" list: the question, what the kid
/// picked, and — when they missed it — the right answer.
class _ReviewCard extends StatelessWidget {
  final int number;
  final AnsweredQuestion answer;
  final AppLang lang;

  const _ReviewCard({
    required this.number,
    required this.answer,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = answer.isCorrect
        ? AppTheme.correct
        : answer.timedOut
        ? Colors.orange.shade700
        : AppTheme.wrong;
    final textTheme = Theme.of(context).textTheme;
    final bodyStyle = textTheme.bodyLarge?.copyWith(
      color: Colors.brown.shade800,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color,
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  answer.question.question.prompt,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.brown.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    style: bodyStyle,
                    children: [
                      TextSpan(text: '${t('your_answer', lang)}: '),
                      TextSpan(
                        text: answer.chosenText ?? t('no_answer', lang),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          decoration: answer.isCorrect || answer.timedOut
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!answer.isCorrect)
                  Text.rich(
                    TextSpan(
                      style: bodyStyle,
                      children: [
                        TextSpan(text: '${t('right_answer', lang)}: '),
                        TextSpan(
                          text: answer.correctText,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.correct,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            answer.isCorrect
                ? '✅'
                : answer.timedOut
                ? '⏰'
                : '❌',
            style: const TextStyle(fontSize: 22),
          ),
        ],
      ),
    );
  }
}

/// One result star; they spin + pop in one after another.
class _Star extends StatelessWidget {
  final bool filled;
  final int index;

  const _Star({required this.filled, required this.index});

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      delay: Duration(milliseconds: 500 + 250 * index),
      from: Offset.zero,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 1100 + 250 * index),
        curve: Interval(
          (500 + 250 * index) / (1100 + 250 * index),
          1,
          curve: Curves.elasticOut,
        ),
        builder: (_, value, child) => Transform.rotate(
          angle: (1 - value) * 3.14,
          child: Transform.scale(scale: value, child: child),
        ),
        child: Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          color: Colors.amber,
          size: 56,
        ),
      ),
    );
  }
}
