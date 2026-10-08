import 'dart:math';

import '../models/question.dart';

/// A question with its choices shuffled for display, keeping track of where
/// the correct answer landed so [QuizEngine] never has to re-derive it.
class ShuffledQuestion {
  final Question question;
  final List<String> displayChoices;
  final int correctDisplayIndex;

  const ShuffledQuestion({
    required this.question,
    required this.displayChoices,
    required this.correctDisplayIndex,
  });

  factory ShuffledQuestion.from(Question question, Random random) {
    final indices = List<int>.generate(question.choices.length, (i) => i)
      ..shuffle(random);
    final displayChoices = indices.map((i) => question.choices[i]).toList();
    final correctDisplayIndex = indices.indexOf(question.correctIndex);
    return ShuffledQuestion(
      question: question,
      displayChoices: displayChoices,
      correctDisplayIndex: correctDisplayIndex,
    );
  }
}

/// What the kid picked for one question, kept so the result screen can
/// walk back through the quiz. [chosenIndex] is -1 when time ran out.
class AnsweredQuestion {
  final ShuffledQuestion question;
  final int chosenIndex;

  const AnsweredQuestion(this.question, this.chosenIndex);

  bool get isCorrect => chosenIndex == question.correctDisplayIndex;
  bool get timedOut => chosenIndex < 0;
  String? get chosenText =>
      timedOut ? null : question.displayChoices[chosenIndex];
  String get correctText =>
      question.displayChoices[question.correctDisplayIndex];
}

/// Drives one play-through: holds the shuffled question order, the current
/// position, and the running score. The random source is pluggable so
/// tests can seed it for deterministic behavior.
class QuizEngine {
  final List<ShuffledQuestion> _questions;
  int _index = 0;
  int _score = 0;
  final List<AnsweredQuestion> _answers = [];

  QuizEngine(List<Question> questions, {Random? random})
    : _questions = questions
          .map((q) => ShuffledQuestion.from(q, random ?? Random()))
          .toList();

  int get total => _questions.length;
  int get currentIndex => _index;
  int get score => _score;
  List<AnsweredQuestion> get answers => List.unmodifiable(_answers);
  bool get isFinished => _index >= _questions.length;

  ShuffledQuestion get currentQuestion => _questions[_index];

  /// Returns whether [choiceIndex] was correct, advances to the next
  /// question, and updates the score.
  bool answer(int choiceIndex) {
    final answered = AnsweredQuestion(currentQuestion, choiceIndex);
    _answers.add(answered);
    final correct = answered.isCorrect;
    if (correct) _score++;
    _index++;
    return correct;
  }
}
