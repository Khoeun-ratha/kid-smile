import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/pack_repository.dart';
import '../logic/quiz_engine.dart';
import '../services/app_language.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/responsive.dart';
import 'result_screen.dart';

class QuizScreen extends StatefulWidget {
  /// Quiz lengths the kid can choose from on the home screen.
  static const lengthOptions = [6, 8, 10];

  final int? categoryId;
  final String categoryTitle;
  final int questionCount;

  const QuizScreen({
    super.key,
    required this.categoryId,
    required this.categoryTitle,
    this.questionCount = 10,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  static const _questionSeconds = 15;

  final _repository = PackRepository();
  QuizEngine? _engine;

  /// Null = not answered yet; otherwise the tapped display index (or -1 for
  /// "time ran out, nothing was tapped"), used to color the buttons and lock
  /// out further taps until we advance.
  int? _selectedIndex;

  /// The question shown while [_selectedIndex] is non-null. [QuizEngine]
  /// advances its index the instant it's answered, which — on the last
  /// question — pushes it past the end of the list before the feedback flash
  /// has finished playing; freezing the question here keeps `build` reading
  /// something in range for the rest of that window.
  ShuffledQuestion? _frozenQuestion;
  int _frozenQuestionNumber = 0;

  int _secondsLeft = _questionSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final language = context.read<AppLanguage>().lang.name;
    final questions = await _repository.getRandomQuestions(
      language: language,
      categoryId: widget.categoryId,
      count: widget.questionCount,
    );
    setState(() => _engine = QuizEngine(questions));
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = _questionSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _timer?.cancel();
        _onChoiceTap(null);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// [displayIndex] is null when the countdown ran out before the kid tapped
  /// anything — treated as a miss, same visual feedback as a wrong tap.
  void _onChoiceTap(int? displayIndex) {
    if (_selectedIndex != null) return; // already answered, waiting to advance
    _timer?.cancel();
    final engine = _engine!;
    setState(() {
      _selectedIndex = displayIndex ?? -1;
      _frozenQuestion = engine.currentQuestion;
      _frozenQuestionNumber = engine.currentIndex;
    });

    engine.answer(displayIndex ?? -1);

    // Slightly longer than before so the shake/pop + emoji burst can finish.
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      if (engine.isFinished) {
        _repository.recordAttempt(
          categoryId: widget.categoryId,
          score: engine.score,
          total: engine.total,
        );
        Navigator.of(context).pushReplacement(
          kidRoute(
            ResultScreen(
              score: engine.score,
              total: engine.total,
              answers: engine.answers,
              categoryTitle: widget.categoryTitle,
              categoryId: widget.categoryId,
              questionCount: widget.questionCount,
            ),
          ),
        );
      } else {
        setState(() => _selectedIndex = null);
        _startTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    if (engine == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (engine.total == 0) {
      final lang = context.watch<AppLanguage>().lang;
      return Scaffold(
        appBar: AppBar(title: Text(widget.categoryTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: KidPanel(child: Text(t('no_questions_yet', lang))),
          ),
        ),
      );
    }

    final showingFeedback = _selectedIndex != null;
    final question = showingFeedback
        ? _frozenQuestion!
        : engine.currentQuestion;
    final questionNumber = showingFeedback
        ? _frozenQuestionNumber
        : engine.currentIndex;
    final lang = context.watch<AppLanguage>();
    final choices = question.displayChoices;
    final answeredCorrectly =
        showingFeedback && _selectedIndex == question.correctDisplayIndex;
    final short = context.isShortScreen;
    final size = MediaQuery.sizeOf(context);
    // Sideways phones and wide windows put the question beside the
    // answers, so they get a wider column to work with.
    final wide = size.width > size.height * 1.3;

    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryTitle)),
      body: MaxWidth(
        maxWidth: wide ? 1000 : (context.isLargeScreen ? 680 : 560),
        child: Stack(
          children: [
            Padding(
              padding: short
                  ? const EdgeInsets.fromLTRB(20, 0, 20, 12)
                  : const EdgeInsets.all(20),
              child: Column(
                children: [
                  KidPanel(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    child: Column(
                      children: [
                        // Fills smoothly instead of jumping a notch per question.
                        TweenAnimationBuilder<double>(
                          tween: Tween(
                            end:
                                (questionNumber + (showingFeedback ? 1 : 0)) /
                                engine.total,
                          ),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          builder: (_, value, _) => LinearProgressIndicator(
                            value: value,
                            minHeight: 10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                '${t('question_label', lang.lang)} '
                                '${localizedNumber(questionNumber + 1, lang.lang)} '
                                '${t('of_label', lang.lang)} '
                                '${localizedNumber(engine.total, lang.lang)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _TimerBadge(
                              secondsLeft: _secondsLeft,
                              totalSeconds: _questionSeconds,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: short ? 10 : 20),
                  Expanded(
                    // Each new question slides in from the right while the
                    // previous one slides out to the left.
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final incoming = child.key == ValueKey(questionNumber);
                        final offset = Tween(
                          begin: Offset(incoming ? 1 : -1, 0),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: offset,
                            child: child,
                          ),
                        );
                      },
                      child: _QuestionView(
                        key: ValueKey(questionNumber),
                        prompt: question.question.prompt,
                        choices: choices,
                        stateFor: (i) =>
                            _stateFor(i, question.correctDisplayIndex),
                        onTap: _onChoiceTap,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showingFeedback)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: _FeedbackBurst(correct: answeredCorrectly),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  _ChoiceState _stateFor(int index, int correctIndex) {
    if (_selectedIndex == null) return _ChoiceState.idle;
    if (index == correctIndex) return _ChoiceState.correct;
    if (index == _selectedIndex) return _ChoiceState.wrong;
    return _ChoiceState.disabled;
  }
}

enum _ChoiceState { idle, correct, wrong, disabled }

class _QuestionView extends StatelessWidget {
  final String prompt;
  final List<String> choices;
  final _ChoiceState Function(int index) stateFor;
  final void Function(int index) onTap;

  const _QuestionView({
    super.key,
    required this.prompt,
    required this.choices,
    required this.stateFor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final promptPanel = KidPanel(
      child: SizedBox(
        width: double.infinity,
        child: Text(
          prompt,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.brown.shade900,
          ),
        ),
      ),
    );
    final gap = context.isShortScreen ? 10.0 : 14.0;
    final choiceTiles = [
      for (var index = 0; index < choices.length; index++)
        Padding(
          padding: EdgeInsets.only(top: index == 0 ? 0 : gap),
          child: FadeSlideIn(
            delay: Duration(milliseconds: 150 + 80 * index),
            from: const Offset(0, 0.6),
            child: _ChoiceButton(
              label: choices[index],
              state: stateFor(index),
              onTap: () => onTap(index),
            ),
          ),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide =
            constraints.maxWidth >= 600 &&
            constraints.maxWidth > constraints.maxHeight * 1.3;
        if (sideBySide) {
          // Landscape / wide: question on the left, answers on the right,
          // each scrolling on its own if it doesn't fit.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(child: SingleChildScrollView(child: promptPanel)),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: choiceTiles,
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        // Portrait: question then answers in one scroll, so a long prompt
        // on a small phone (or with big system text) never overflows.
        return ListView(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          children: [
            promptPanel,
            SizedBox(height: gap * 2),
            ...choiceTiles,
          ],
        );
      },
    );
  }
}

/// Big emoji that pops up over the question for a moment after answering.
class _FeedbackBurst extends StatelessWidget {
  final bool correct;

  const _FeedbackBurst({required this.correct});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (_, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: Transform.scale(scale: value, child: child),
      ),
      child: Text(
        correct ? '🎉' : '😅',
        style: TextStyle(
          fontSize: switch (context.screenClass) {
            ScreenClass.short => 72,
            ScreenClass.phone => 96,
            ScreenClass.large => 128,
          },
        ),
      ),
    );
  }
}

class _TimerBadge extends StatelessWidget {
  final int secondsLeft;
  final int totalSeconds;

  const _TimerBadge({required this.secondsLeft, required this.totalSeconds});

  @override
  Widget build(BuildContext context) {
    final urgent = secondsLeft <= totalSeconds ~/ 3;
    final color = urgent ? AppTheme.wrong : AppTheme.primary;
    // When time is running low, every tick "thumps" the badge.
    return TweenAnimationBuilder<double>(
      key: ValueKey(urgent ? secondsLeft : -1),
      tween: Tween(begin: urgent ? 1.3 : 1.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              '${secondsLeft}s',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final _ChoiceState state;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.label,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color background = switch (state) {
      _ChoiceState.idle => Colors.white,
      _ChoiceState.correct => AppTheme.correct,
      _ChoiceState.wrong => AppTheme.wrong,
      _ChoiceState.disabled => Colors.grey.shade300,
    };
    final isColored =
        state == _ChoiceState.correct || state == _ChoiceState.wrong;
    final textStyle = Theme.of(context).textTheme.titleLarge!.copyWith(
      fontWeight: FontWeight.bold,
      color: isColored ? Colors.white : Colors.brown.shade900,
    );

    return Shake(
      trigger: state == _ChoiceState.wrong,
      child: Pop(
        trigger: state == _ChoiceState.correct,
        child: Bouncy(
          onTap: state == _ChoiceState.idle ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: context.isShortScreen ? 12 : 18,
              horizontal: 16,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isColored
                      ? background.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.08),
                  blurRadius: isColored ? 14 : 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 28),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: textStyle,
                    child: Text(label, textAlign: TextAlign.center),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: isColored
                        ? Icon(
                            state == _ChoiceState.correct
                                ? Icons.check_circle
                                : Icons.cancel,
                            key: ValueKey(state),
                            color: Colors.white,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
