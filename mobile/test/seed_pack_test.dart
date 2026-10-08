import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kid_smile/models/pack.dart';

QuestionPack _load(String path) => QuestionPack.fromJson(
  jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
);

void main() {
  final en = _load('assets/seed_pack.json');
  final km = _load('assets/seed_pack_km.json');

  test('Khmer seed pack is tagged Khmer and internally consistent', () {
    expect(km.categories, isNotEmpty);
    expect(km.questions, isNotEmpty);
    final categoryIds = km.categories.map((c) => c.id).toSet();
    for (final c in km.categories) {
      expect(c.language, 'km');
    }
    for (final q in km.questions) {
      expect(q.language, 'km');
      expect(categoryIds, contains(q.categoryId));
      expect(q.correctIndex, inInclusiveRange(0, q.choices.length - 1));
    }
  });

  test('both packs ship at least 400 valid questions', () {
    for (final pack in [en, km]) {
      expect(pack.questions.length, greaterThanOrEqualTo(400));
      expect(pack.seedRevision, greaterThan(0));
      final ids = pack.questions.map((q) => q.id).toSet();
      expect(ids, hasLength(pack.questions.length));
      for (final q in pack.questions) {
        expect(q.choices.toSet(), hasLength(q.choices.length));
        expect(q.correctIndex, inInclusiveRange(0, q.choices.length - 1));
      }
    }
  });

  test('Khmer seed ids never collide with English rows', () {
    // Both languages share the same SQLite tables keyed by id.
    final enCategoryIds = en.categories.map((c) => c.id).toSet();
    final enQuestionIds = en.questions.map((q) => q.id).toSet();
    for (final c in km.categories) {
      expect(enCategoryIds, isNot(contains(c.id)));
    }
    for (final q in km.questions) {
      expect(enQuestionIds, isNot(contains(q.id)));
    }
  });
}
