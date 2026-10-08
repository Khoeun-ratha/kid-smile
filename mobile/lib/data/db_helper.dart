import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/pack.dart';

/// Owns the single on-device SQLite database that the whole app plays
/// against offline. English and Khmer are independent content sets sharing
/// this database (tagged by a `language` column) — importing a pack for one
/// language only replaces that language's rows, so a device that's synced
/// both languages can switch between them offline without re-fetching.
class DbHelper {
  DbHelper._();
  static final DbHelper instance = DbHelper._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'kid_smile.db');

    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await _createContentTables(db);
        await db.execute('''
          CREATE TABLE quiz_attempts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category_id INTEGER,
            score INTEGER NOT NULL,
            total INTEGER NOT NULL,
            played_at TEXT NOT NULL
          )
        ''');
      },
      // `categories`/`questions` are always wholesale-replaced by the next
      // seed/sync anyway (see [importPack]), so recreating them empty on any
      // schema change is simpler and just as safe as ALTER TABLE — only
      // `quiz_attempts` (the kid's local play history) must survive.
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('DROP TABLE IF EXISTS categories');
        await db.execute('DROP TABLE IF EXISTS questions');
        await _createContentTables(db);
      },
    );
  }

  Future<void> _createContentTables(Database db) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        language TEXT NOT NULL,
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        sort_order INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE questions (
        id INTEGER PRIMARY KEY,
        category_id INTEGER NOT NULL,
        prompt TEXT NOT NULL,
        choices TEXT NOT NULL,
        language TEXT NOT NULL,
        correct_index INTEGER NOT NULL,
        difficulty TEXT NOT NULL,
        age_group TEXT NOT NULL
      )
    ''');
  }

  Future<bool> hasContent(String language) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM questions WHERE language = ?',
      [language],
    );
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }

  /// Loads the bundled seed pack for [language] (shipped in assets) — used
  /// on first launch so the quiz is playable offline with zero setup.
  Future<QuestionPack> loadSeedPack(String language) async {
    final asset = language == 'en'
        ? 'assets/seed_pack.json'
        : 'assets/seed_pack_$language.json';
    final raw = await rootBundle.loadString(asset);
    return QuestionPack.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Replaces this device's [language] content with [pack] in one
  /// transaction — content for any other language already cached locally is
  /// left untouched. Called for the initial seed import and for every
  /// successful background sync.
  Future<void> importPack(QuestionPack pack, String language) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'questions',
        where: 'language = ?',
        whereArgs: [language],
      );
      await txn.delete(
        'categories',
        where: 'language = ?',
        whereArgs: [language],
      );
      for (final category in pack.categories) {
        await txn.insert('categories', category.toMap());
      }
      for (final question in pack.questions) {
        await txn.insert('questions', question.toMap());
      }
    });
  }

  Future<void> recordAttempt({
    required int? categoryId,
    required int score,
    required int total,
  }) async {
    final db = await database;
    await db.insert('quiz_attempts', {
      'category_id': categoryId,
      'score': score,
      'total': total,
      'played_at': DateTime.now().toIso8601String(),
    });
  }
}
