import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'app_language.dart';
import 'sync_service.dart';

/// App-wide connection state plus automatic background sync.
///
/// The quiz always plays from local SQLite, so being offline never blocks
/// anything; this only decides *when* to quietly refresh content:
/// at startup, and every time the device comes back online. Both
/// languages are refreshed so a kid can switch language later with no
/// connection and still get the latest questions.
class ContentSync extends ChangeNotifier {
  final SyncService _sync;
  final Stream<List<ConnectivityResult>>? _changes;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ContentSync({
    SyncService? sync,
    Stream<List<ConnectivityResult>>? connectivityChanges,
  }) : _sync = sync ?? SyncService(),
       _changes = connectivityChanges;

  bool _online = true;

  /// Whether the device has a network connection (it may still be unable
  /// to reach the server; [syncLanguage] reports that separately).
  bool get online => _online;

  int _contentVersion = 0;

  /// Bumped whenever a sync imported new questions; screens showing
  /// question data watch it and reload.
  int get contentVersion => _contentVersion;

  Future<void> _queue = Future.value();

  /// Starts watching the connection. Call once, after the bundled packs
  /// are seeded, so a sync can never race the seed import.
  Future<void> start() async {
    if (_subscription != null) return;
    final connectivity = Connectivity();
    _subscription = (_changes ?? connectivity.onConnectivityChanged).listen(
      _onConnectivity,
      onError: (_) {}, // no connectivity plugin (e.g. tests)
    );
    try {
      _onConnectivity(await connectivity.checkConnectivity());
    } catch (_) {
      // No connectivity plugin (e.g. tests): assume online and let the
      // HTTP call itself decide.
      _onConnectivity(const [ConnectivityResult.other]);
    }
  }

  /// True once this online stretch has been synced; reset on going
  /// offline, so every reconnect triggers exactly one refresh (switching
  /// between Wi-Fi and mobile data doesn't count as a reconnect).
  bool _syncedThisSession = false;

  void _onConnectivity(List<ConnectivityResult> results) {
    final online = !results.every((r) => r == ConnectivityResult.none);
    if (online != _online) {
      _online = online;
      notifyListeners();
    }
    if (!online) {
      _syncedThisSession = false;
      return;
    }
    if (_syncedThisSession) return;
    _syncedThisSession = true;
    for (final lang in AppLang.values) {
      unawaited(syncLanguage(lang.name));
    }
  }

  /// Syncs one language now. Calls are queued, never run in parallel, so
  /// two imports can't interleave in the database.
  Future<SyncStatus> syncLanguage(String language) {
    final result = _queue.then((_) => _sync.syncIfOnline(language));
    _queue = result.then((_) {}, onError: (_) {});
    return result.then((status) {
      if (status == SyncStatus.updated) {
        _contentVersion++;
        notifyListeners();
      }
      return status;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
