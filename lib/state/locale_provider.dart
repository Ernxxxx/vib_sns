import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the app's locale setting.
/// Users can choose: system default, Japanese, or English.
class LocaleProvider extends ChangeNotifier {
  static const _prefsKey = 'app_locale';

  Locale? _locale;

  /// Current locale. If null, follows system setting.
  Locale? get locale => _locale;

  LocaleProvider() {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_prefsKey);
    if (savedCode != null && savedCode.isNotEmpty) {
      _locale = Locale(savedCode);
      notifyListeners();
    }
  }

  /// Set locale. Pass null to use system default.
  Future<void> setLocale(Locale? newLocale) async {
    _locale = newLocale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (newLocale == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, newLocale.languageCode);
    }
  }

  /// Convenience method to set to Japanese
  Future<void> setJapanese() => setLocale(const Locale('ja'));

  /// Convenience method to set to English
  Future<void> setEnglish() => setLocale(const Locale('en'));

  /// Convenience method to use system default
  Future<void> setSystemDefault() => setLocale(null);
}
