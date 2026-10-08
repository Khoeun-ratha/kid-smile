import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../logic/question_picker.dart';
import '../models/category.dart';
import '../models/question.dart';
import 'db_helper.dart';

const String _kPackVersionKeyPrefix = 'pack_version_';
const String _kSeedRevisionKeyPrefix = 'seed_revision_';
const String _kServerContentKeyPrefix = 'server_content_';

/// The single point every screen goes through to read quiz content or
/// record a played attempt. Everything here reads/writes local SQLite only
/// — no network calls live in this class, so callers never need to think
/// about connectivity to play the quiz. Every read/sync is scoped to one
/// language at a time, since English and Khmer are independent content sets.
class PackRepository {
  final DbHelper _dbHelper;
  PackRepository({DbHelper? dbHelper})
    : _dbHelper = dbHelper ?? DbHelper.instance;

  /// Ensures every language has playable content on disk, so both work
  /// offline on a brand-new install.
  ///
  /// English ships the real starter pack. Khmer ships a placeholder pack
  /// (ids 9001+/90001+ so they never collide with server rows in the shared
  /// tables) whose local version is deliberately left at 0: the first sync
  /// that returns real Khmer content always replaces it.
  ///
  /// A bundled pack is also re-imported when the app ships a newer
  /// `seed_revision` than the one on disk — unless that language's content
  /// has since come from the server, which always wins over bundled data.
  Future<void> ensureSeeded() async {
    final prefs = await SharedPreferences.getInstance();
    for (final language in const ['en', 'km']) {
      if (prefs.getBool('$_kServerContentKeyPrefix$language') ?? false) {
        continue;
      }
      final hasContent = await _dbHelper.hasContent(language);
      final storedRevision =
          prefs.getInt('$_kSeedRevisionKeyPrefix$language') ?? 0;
      final seed = await _dbHelper.loadSeedPack(language);
      if (hasContent && storedRevision >= seed.seedRevision) continue;

      await _dbHelper.importPack(seed, language);
      await prefs.setInt(
        '$_kSeedRevisionKeyPrefix$language',
        seed.seedRevision,
      );
      if (language == 'en') {
        await setLocalPackVersion(language, seed.version);
      }
    }
  }

  /// Records that [language]'s local content now comes from the server, so
  /// [ensureSeeded] never overwrites it with bundled data again.
  Future<void> markServerContent(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_kServerContentKeyPrefix$language', true);
  }

  Future<int> getLocalPackVersion(String language) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_kPackVersionKeyPrefix$language') ?? 0;
  }

  Future<void> setLocalPackVersion(String language, int version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_kPackVersionKeyPrefix$language', version);
  }

  Future<List<QuizCategory>> getCategories(String language) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'categories',
      where: 'language = ?',
      whereArgs: [language],
      orderBy: 'sort_order ASC',
    );
    return rows.map(QuizCategory.fromMap).toList();
  }

  /// Questions served by recent quizzes, oldest first, so the next quiz
  /// can steer around them. In-memory only: a fresh launch starting fresh
  /// is fine.
  static final List<int> _recentIds = [];
  static const _recentLimit = 60;

  /// Picks [count] random questions in [language], optionally restricted to
  /// [categoryId] (null = mixed across all categories in that language).
  /// See [pickQuestionIds] for how they're chosen; only ids are scanned
  /// here, so this stays cheap even with hundreds of questions.
  Future<List<Question>> getRandomQuestions({
    required String language,
    int? categoryId,
    int count = 10,
  }) async {
    final db = await _dbHelper.database;
    final where = categoryId != null
        ? 'language = ? AND category_id = ?'
        : 'language = ?';
    final whereArgs = categoryId != null ? [language, categoryId] : [language];
    final rows = await db.query(
      'questions',
      columns: ['id', 'category_id'],
      where: where,
      whereArgs: whereArgs,
    );
    final ids = pickQuestionIds(
      pool: [
        for (final r in rows)
          (id: r['id'] as int, categoryId: r['category_id'] as int),
      ],
      count: count,
      recent: _recentIds,
    );
    if (ids.isEmpty) return [];

    _recentIds
      ..removeWhere(ids.contains)
      ..addAll(ids);
    if (_recentIds.length > _recentLimit) {
      _recentIds.removeRange(0, _recentIds.length - _recentLimit);
    }

    final full = await db.query(
      'questions',
      where: 'id IN (${List.filled(ids.length, '?').join(', ')})',
      whereArgs: ids,
    );
    final byId = {for (final r in full) r['id'] as int: Question.fromMap(r)};
    return [for (final id in ids) ?byId[id]];
  }

  /// How much playable content is cached locally for [language].
  Future<({int categories, int questions})> getContentCounts(
    String language,
  ) async {
    final db = await _dbHelper.database;
    Future<int> count(String table) async =>
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $table WHERE language = ?', [
            language,
          ]),
        ) ??
        0;
    return (
      categories: await count('categories'),
      questions: await count('questions'),
    );
  }

  /// Summary of every quiz played on this device (across both languages).
  /// Percentages are 0–100.
  Future<({int games, int bestPercent, int averagePercent, int perfect})>
  getPlayStats() async {
    final db = await _dbHelper.database;
    final row = (await db.rawQuery('''
      SELECT
        COUNT(*) AS games,
        MAX(score * 100 / total) AS best,
        AVG(score * 100.0 / total) AS average,
        SUM(CASE WHEN score = total THEN 1 ELSE 0 END) AS perfect
      FROM quiz_attempts
      WHERE total > 0
    ''')).first;
    return (
      games: (row['games'] as int?) ?? 0,
      bestPercent: (row['best'] as int?) ?? 0,
      averagePercent: ((row['average'] as num?) ?? 0).round(),
      perfect: (row['perfect'] as int?) ?? 0,
    );
  }

  Future<void> recordAttempt({
    int? categoryId,
    required int score,
    required int total,
  }) {
    return _dbHelper.recordAttempt(
      categoryId: categoryId,
      score: score,
      total: total,
    );
  }
}
