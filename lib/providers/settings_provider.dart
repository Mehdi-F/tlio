import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

enum AppThemeMode { light, dark, auto }

class SettingsProvider extends ChangeNotifier {
  static const _themeModeKey = 'settings_theme_mode';
  static const _languageKey = 'settings_language';

  AppThemeMode _themeMode = AppThemeMode.auto;
  String _language = 'fr';

  AppThemeMode get themeMode => _themeMode;
  String get language => _language;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = AppThemeMode.values[prefs.getInt(_themeModeKey) ?? 2];
    _language = prefs.getString(_languageKey) ?? 'fr';
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    if (!AppConstants.supportedLanguages.contains(lang)) {
      throw ArgumentError('Unsupported language: $lang. Supported: ${AppConstants.supportedLanguages.join(", ")}');
    }
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, lang);
    notifyListeners();
  }
}
