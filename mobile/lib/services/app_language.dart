import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kLanguageKey = 'app_language';

/// The two languages the app ships content in. Kept as a tiny enum rather
/// than a raw string so callers can't typo a language code.
enum AppLang { en, km }

/// App-wide current language, persisted across launches. Not every
/// category/question has a Khmer translation yet, so screens fall back to
/// English per-item rather than this service enforcing completeness.
class AppLanguage extends ChangeNotifier {
  AppLang _lang = AppLang.en;
  AppLang get lang => _lang;
  bool get isKm => _lang == AppLang.km;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLanguageKey);
    _lang = saved == 'km' ? AppLang.km : AppLang.en;
    notifyListeners();
  }

  Future<void> setLang(AppLang lang) async {
    if (_lang == lang) return;
    _lang = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguageKey, lang.name);
  }
}
