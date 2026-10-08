import 'dart:convert';

class Question {
  final int id;
  final int categoryId;
  final String prompt;
  final List<String> choices;
  final String language;
  final int correctIndex;
  final String difficulty;
  final String ageGroup;

  const Question({
    required this.id,
    required this.categoryId,
    required this.prompt,
    required this.choices,
    required this.language,
    required this.correctIndex,
    required this.difficulty,
    required this.ageGroup,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as int,
      categoryId: json['category_id'] as int,
      prompt: json['prompt'] as String,
      choices: List<String>.from(json['choices'] as List),
      language: json['language'] as String? ?? 'en',
      correctIndex: json['correct_index'] as int,
      difficulty: json['difficulty'] as String? ?? 'easy',
      ageGroup: json['age_group'] as String? ?? '4-6',
    );
  }

  /// Rows in SQLite store `choices` as a JSON-encoded string since sqflite
  /// has no native list column type.
  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'] as int,
      categoryId: map['category_id'] as int,
      prompt: map['prompt'] as String,
      choices: List<String>.from(jsonDecode(map['choices'] as String) as List),
      language: map['language'] as String,
      correctIndex: map['correct_index'] as int,
      difficulty: map['difficulty'] as String,
      ageGroup: map['age_group'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'prompt': prompt,
      'choices': jsonEncode(choices),
      'language': language,
      'correct_index': correctIndex,
      'difficulty': difficulty,
      'age_group': ageGroup,
    };
  }
}
