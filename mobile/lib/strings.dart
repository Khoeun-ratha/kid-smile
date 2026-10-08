import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'services/app_language.dart';

/// Fixed UI strings, one JSON file per language (`assets/i18n/en.json`,
/// `assets/i18n/km.json`) — plain key/value files a translator can edit
/// without touching Dart, mirroring how question/category content is
/// bilingual data rather than code. Loaded once at startup; [t] then reads
/// from memory so call sites stay synchronous.
class AppStrings {
  static Map<String, String> _en = {};
  static Map<String, String> _km = {};
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    _en = await _loadTable('assets/i18n/en.json');
    _km = await _loadTable('assets/i18n/km.json');
    _loaded = true;
  }

  static Future<Map<String, String>> _loadTable(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return Map<String, String>.from(jsonDecode(raw) as Map);
  }
}

String t(String key, AppLang lang) {
  final table = lang == AppLang.km ? AppStrings._km : AppStrings._en;
  return table[key] ?? AppStrings._en[key] ?? key;
}

/// Writes [n] with Khmer digits (០–៩) when playing in Khmer.
String localizedNumber(int n, AppLang lang) {
  if (lang != AppLang.km) return '$n';
  const digits = '០១២៣៤៥៦៧៨៩';
  return '$n'.split('').map((d) => digits[int.parse(d)]).join();
}
