import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kid_smile/logic/question_picker.dart';

/// [perCategory] questions in each of [categories] categories; ids are
/// `category * 1000 + n`.
List<({int id, int categoryId})> _pool(int categories, int perCategory) => [
  for (var c = 1; c <= categories; c++)
    for (var n = 0; n < perCategory; n++) (id: c * 1000 + n, categoryId: c),
];

void main() {
  test('returns the requested number of distinct questions', () {
    for (final count in [6, 8, 10]) {
      final ids = pickQuestionIds(pool: _pool(5, 50), count: count);
      expect(ids, hasLength(count));
      expect(ids.toSet(), hasLength(count));
    }
  });

  test('mixed quizzes spread evenly across categories', () {
    // One huge category must not crowd out the small ones.
    final pool = [
      ..._pool(4, 10),
      for (var n = 0; n < 300; n++) (id: n, categoryId: 99),
    ];
    final ids = pickQuestionIds(pool: pool, count: 10, random: Random(1));
    final perCategory = <int, int>{};
    for (final id in ids) {
      final category = pool.firstWhere((q) => q.id == id).categoryId;
      perCategory[category] = (perCategory[category] ?? 0) + 1;
    }
    expect(perCategory.keys, hasLength(5));
    expect(perCategory.values, everyElement(2));
  });

  test('avoids recently played questions while enough fresh ones remain', () {
    final pool = _pool(1, 30);
    final recent = [for (final q in pool.take(20)) q.id];
    final ids = pickQuestionIds(pool: pool, count: 10, recent: recent);
    expect(ids.toSet().intersection(recent.toSet()), isEmpty);
  });

  test('reuses the least recently played questions when the pool is small', () {
    final pool = _pool(1, 8);
    final recent = [for (final q in pool) q.id]; // all played, oldest first
    final ids = pickQuestionIds(pool: pool, count: 6, recent: recent);
    expect(ids.toSet(), equals(recent.take(6).toSet()));
  });

  test('is random: different seeds give different quizzes', () {
    final pool = _pool(5, 50);
    final a = pickQuestionIds(pool: pool, count: 10, random: Random(1));
    final b = pickQuestionIds(pool: pool, count: 10, random: Random(2));
    expect(a, isNot(equals(b)));
  });

  test('returns what exists when the pool is smaller than asked', () {
    expect(pickQuestionIds(pool: _pool(1, 4), count: 10), hasLength(4));
    expect(pickQuestionIds(pool: const [], count: 10), isEmpty);
  });
}
