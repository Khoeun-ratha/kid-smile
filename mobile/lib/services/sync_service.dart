import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../data/db_helper.dart';
import '../data/pack_repository.dart';
import '../models/pack.dart';

enum SyncStatus { offline, upToDate, updated, error }

/// Best-effort background sync: if the device is online, ask the API
/// whether a newer question pack exists for the given language and import
/// it. Every step is optional-on-failure — the quiz already works from
/// local data, so a failed sync just leaves the app exactly as playable as
/// before.
class SyncService {
  final PackRepository _repository;
  final String baseUrl;

  SyncService({
    PackRepository? repository,
    // No API_URL means an offline-only build that plays the bundled packs
    // and never contacts a server. Builds that should sync pass one:
    // flutter run --dart-define=API_URL=http://192.168.8.169:8000
    this.baseUrl = const String.fromEnvironment('API_URL'),
  }) : _repository = repository ?? PackRepository();

  /// False for offline-only builds (no API_URL).
  bool get enabled => baseUrl.isNotEmpty;

  Future<SyncStatus> syncIfOnline(String language) async {
    if (!enabled) return SyncStatus.offline;
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = !connectivity.contains(ConnectivityResult.none);
    if (!isOnline) return SyncStatus.offline;

    try {
      final localVersion = await _repository.getLocalPackVersion(language);
      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/pack?since_version=$localVersion&language=$language',
            ),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 204) return SyncStatus.upToDate;
      if (response.statusCode != 200) return SyncStatus.error;

      final pack = QuestionPack.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      if (pack.version <= localVersion) return SyncStatus.upToDate;
      // The server has nothing for this language yet; keep what's on the
      // device (e.g. the bundled starter pack) rather than wiping it.
      if (pack.questions.isEmpty) return SyncStatus.upToDate;

      await DbHelper.instance.importPack(pack, language);
      await _repository.setLocalPackVersion(language, pack.version);
      await _repository.markServerContent(language);
      return SyncStatus.updated;
    } catch (_) {
      return SyncStatus.error;
    }
  }
}
