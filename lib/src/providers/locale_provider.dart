import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';

class LocaleProvider with ChangeNotifier {
  static const String _prefKey = 'language_code';
  String _locale = 'en';

  String get locale => _locale;

  Future<void> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    _locale = prefs.getString(_prefKey) ?? 'en';
    notifyListeners();
  }

  Future<void> setLocale(String languageCode) async {
    if (_locale == languageCode) return;
    _locale = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, languageCode);
    notifyListeners();
  }

  void toggleLocale() {
    setLocale(_locale == 'en' ? 'id' : 'en');
  }

  String get(String key) {
    return AppLocalizations.get(key, _locale);
  }
}
