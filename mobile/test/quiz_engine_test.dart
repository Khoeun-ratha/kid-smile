import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kid_smile/logic/quiz_engine.dart';
import 'package:kid_smile/models/question.dart';

Question _question(int id, {int correctIndex = 0}) {
  return Question(
    id: id,
    categoryId: 1,
    prompt: 'Question $id',
    choices: const ['A', 'B', 'C', 'D'],
    language: 'en',
    correctIndex: correctIndex,
    difficulty: 'easy',
    ageGroup: '4-6',
  );
}

void main() {
  group('QuizEngine', () {
    test('tracks score across correct and incorrect answers', () {
      final engine = QuizEngine([
        _question(1, correctIndex: 0),
        _question(2, correctIndex: 0),
      ], random: Random(1));

      final firstCorrectIndex = engine.currentQuestion.correctDisplayIndex;
      engine.answer(firstCorrectIndex); // correct
      final secondCorrectIndex = engine.currentQuestion.correctDisplayIndex;
      engine.answer((secondCorrectIndex + 1) % 4); // wrong

      expect(engine.score, 1);
      expect(engine.isFinished, isTrue);
    });

    test(
      'shuffled choices contain the same options as the source question',
      () {
        final question = _question(1, correctIndex: 2);
        final engine = QuizEngine([question], random: Random(42));

        final shuffled = engine.currentQuestion;
        expect(
          shuffled.displayChoices.toSet(),
          equals(question.choices.toSet()),
        );
        expect(
          shuffled.displayChoices[shuffled.correctDisplayIndex],
          equals(question.choices[question.correctIndex]),
        );
      },
    );

    test('isFinished is false until every question has been answered', () {
      final engine = QuizEngine([
        _question(1),
        _question(2),
        _question(3),
      ], random: Random(7));

      expect(engine.isFinished, isFalse);
      engine.answer(0);
      expect(engine.isFinished, isFalse);
      engine.answer(0);
      expect(engine.isFinished, isFalse);
      engine.answer(0);
      expect(engine.isFinished, isTrue);
    });

    test('records each answer for the review list, including timeouts', () {
      final engine = QuizEngine([
        _question(1, correctIndex: 1),
        _question(2),
        _question(3),
      ], random: Random(3));

      final firstCorrect = engine.currentQuestion.correctDisplayIndex;
      engine.answer(firstCorrect);
      final secondWrong = (engine.currentQuestion.correctDisplayIndex + 1) % 4;
      engine.answer(secondWrong);
      engine.answer(-1); // time ran out

      final answers = engine.answers;
      expect(answers, hasLength(3));
      expect(answers[0].isCorrect, isTrue);
      expect(answers[0].chosenText, 'B');
      expect(answers[1].isCorrect, isFalse);
      expect(answers[1].timedOut, isFalse);
      expect(answers[1].correctText, 'A');
      expect(answers[2].timedOut, isTrue);
      expect(answers[2].chosenText, isNull);
    });
  });
}
