import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kid_smile/services/content_sync.dart';
import 'package:kid_smile/services/sync_service.dart';

/// Records calls instead of touching the network; tracks overlap so we can
/// prove syncs never run in parallel.
class _FakeSync extends SyncService {
  _FakeSync({super.baseUrl = 'http://test.invalid'});

  final calls = <String>[];
  SyncStatus result = SyncStatus.upToDate;
  int _running = 0;
  int maxConcurrent = 0;

  @override
  Future<SyncStatus> syncIfOnline(String language) async {
    calls.add(language);
    _running++;
    if (_running > maxConcurrent) maxConcurrent = _running;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    _running--;
    return result;
  }
}

Future<void> _flush() => Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSync fake;
  late StreamController<List<ConnectivityResult>> network;
  late ContentSync sync;

  setUp(() {
    fake = _FakeSync();
    network = StreamController<List<ConnectivityResult>>();
    sync = ContentSync(sync: fake, connectivityChanges: network.stream);
  });

  tearDown(() {
    sync.dispose();
    network.close();
  });

  test('offline-only build (no API_URL) never syncs', () async {
    final offline = _FakeSync(baseUrl: '');
    final offlineSync = ContentSync(
      sync: offline,
      connectivityChanges: const Stream.empty(),
    );
    addTearDown(offlineSync.dispose);
    expect(offlineSync.enabled, isFalse);
    await offlineSync.start();
    await _flush();
    expect(offline.calls, isEmpty);
  });

  test('syncs both languages at startup', () async {
    await sync.start();
    await _flush();
    expect(fake.calls, ['en', 'km']);
  });

  test('goes offline, then re-syncs exactly once on reconnect', () async {
    await sync.start();
    await _flush();
    fake.calls.clear();

    network.add([ConnectivityResult.none]);
    await _flush();
    expect(sync.online, isFalse);
    expect(fake.calls, isEmpty);

    network.add([ConnectivityResult.wifi]);
    await _flush();
    expect(sync.online, isTrue);
    expect(fake.calls, ['en', 'km']);

    // Switching networks while still online is not a reconnect.
    network.add([ConnectivityResult.mobile]);
    await _flush();
    expect(fake.calls, ['en', 'km']);
  });

  test('new content bumps contentVersion so screens reload', () async {
    fake.result = SyncStatus.updated;
    var notified = 0;
    sync.addListener(() => notified++);
    final status = await sync.syncLanguage('km');
    expect(status, SyncStatus.updated);
    expect(sync.contentVersion, 1);
    expect(notified, 1);

    fake.result = SyncStatus.upToDate;
    await sync.syncLanguage('km');
    expect(sync.contentVersion, 1);
  });

  test('syncs are queued, never run in parallel', () async {
    await Future.wait([
      sync.syncLanguage('en'),
      sync.syncLanguage('km'),
      sync.syncLanguage('en'),
    ]);
    expect(fake.maxConcurrent, 1);
    expect(fake.calls, ['en', 'km', 'en']);
  });

  test('every Baloo 2 weight the app uses is bundled for offline use', () {
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ]) {
      final file = File('assets/google_fonts/Baloo2-$weight.ttf');
      expect(file.existsSync(), isTrue, reason: file.path);
      expect(file.lengthSync(), greaterThan(100000));
    }
    expect(File('assets/google_fonts/OFL.txt').existsSync(), isTrue);
  });
}
