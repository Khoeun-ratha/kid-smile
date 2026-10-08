class QuizCategory {
  final int id;
  final String name;
  final String language;
  final String icon;
  final String color;
  final int sortOrder;

  const QuizCategory({
    required this.id,
    required this.name,
    required this.language,
    required this.icon,
    required this.color,
    required this.sortOrder,
  });

  factory QuizCategory.fromMap(Map<String, dynamic> map) {
    return QuizCategory(
      id: map['id'] as int,
      name: map['name'] as String,
      language: map['language'] as String? ?? 'en',
      icon: map['icon'] as String,
      color: map['color'] as String,
      sortOrder: map['sort_order'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'language': language,
      'icon': icon,
      'color': color,
      'sort_order': sortOrder,
    };
  }
}
