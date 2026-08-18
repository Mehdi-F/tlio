import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'app_strings.dart';

extension LocalizationContext on BuildContext {
  String get currentLanguage => read<SettingsProvider>().language;

  String tr(String key) => AppStrings.get(key, language: currentLanguage);

  String watchTr(String key) {
    final settings = watch<SettingsProvider>();
    return AppStrings.get(key, language: settings.language);
  }
}
