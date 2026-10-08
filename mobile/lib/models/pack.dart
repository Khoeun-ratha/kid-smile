import 'category.dart';
import 'question.dart';

class QuestionPack {
  final int version;

  /// Only set on the bundled offline packs: bumped whenever the bundled
  /// content changes, so installs that seeded an older copy re-import it.
  final int seedRevision;
  final List<QuizCategory> categories;
  final List<Question> questions;

  const QuestionPack({
    required this.version,
    this.seedRevision = 0,
    required this.categories,
    required this.questions,
  });

  factory QuestionPack.fromJson(Map<String, dynamic> json) {
    return QuestionPack(
      version: json['version'] as int,
      seedRevision: json['seed_revision'] as int? ?? 0,
      categories: (json['categories'] as List)
          .map((c) => QuizCategory.fromMap(c as Map<String, dynamic>))
          .toList(),
      questions: (json['questions'] as List)
          .map((q) => Question.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }
}
