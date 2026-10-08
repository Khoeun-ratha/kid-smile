import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kid_smile/data/db_helper.dart';
import 'package:kid_smile/data/pack_repository.dart';
import 'package:kid_smile/models/pack.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A device that once synced a small server pack, then got an offline-only
/// build: the bundled packs must win again, or it's stuck with the server's
/// handful of questions forever.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  final repository = PackRepository();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    tmp = await Directory.systemTemp.createTemp('kid_smile_test');
    await databaseFactory.setDatabasesPath(tmp.path);
  });

  tearDownAll(() async {
    await (await DbHelper.instance.database).close();
    await tmp.delete(recursive: true);
  });

  Future<int> questionCount(String language) async =>
      (await repository.getContentCounts(language)).questions;

  Future<void> simulateServerSync() async {
    final bundled = await DbHelper.instance.loadSeedPack('en');
    final serverPack = QuestionPack(
      version: 3,
      categories: bundled.categories.take(1).toList(),
      questions: bundled.questions.take(2).toList(),
    );
    await DbHelper.instance.importPack(serverPack, 'en');
    await repository.markServerContent('en');
    await repository.setLocalPackVersion('en', 3);
  }

  test('sync-enabled build keeps content that came from the server', () async {
    SharedPreferences.setMockInitialValues({});
    await repository.ensureSeeded();
    await simulateServerSync();

    await repository.ensureSeeded(serverSync: true);

    expect(await questionCount('en'), 2);
  });

  test('offline-only build replaces stale server content with the bundled '
      'pack', () async {
    SharedPreferences.setMockInitialValues({});
    await repository.ensureSeeded();
    final bundledCount = await questionCount('en');
    await simulateServerSync();
    expect(await questionCount('en'), 2);

    await repository.ensureSeeded(serverSync: false);

    expect(await questionCount('en'), bundledCount);
    expect(bundledCount, greaterThan(500));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('server_content_en'), isNull);
    expect(await repository.getLocalPackVersion('en'), 1);
  });
}
