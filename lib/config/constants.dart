class AppConstants {
  AppConstants._();

  // Durations
  static const requestTimeout = Duration(seconds: 12);
  static const cacheTtl = Duration(hours: 6);

  // Pagination
  static const libraryPageSize = 21;
  static const initialLoadTimeout = Duration(milliseconds: 600);

  // UI
  static const posterAspectRatio = 0.67;
  static const maxAuthors = 3;

  // Localization
  static const supportedLanguages = {'fr', 'en'};
  static const defaultLanguage = 'fr';
}
