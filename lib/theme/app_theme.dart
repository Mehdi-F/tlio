import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // Dark theme colors
  static const background = Color(0xFF1C1712);
  static const surface = Color(0xFF29221A);
  static const surfaceVariant = Color(0xFF362D22);
  static const accent = Color(0xFFD97B4F);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFAFA396);

  // Light theme colors
  static const lightBackground = Color(0xFFFAF6EF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceVariant = Color(0xFFF0E9DD);
  static const lightTextPrimary = Colors.black;
  static const lightTextSecondary = Color(0xFF6B6153);
}

/// AppColors' fields are fixed dark-mode values by themselves — widgets that
/// referenced them directly stayed dark even when the user picked light
/// theme. These getters resolve the right variant from the active
/// [Theme], the same way [buildAppTheme] already does for Material's own
/// widgets (AppBar, Chip, etc).
extension AppColorsContext on BuildContext {
  bool get _isDarkMode => Theme.of(this).brightness == Brightness.dark;
  Color get colorBackground => _isDarkMode ? AppColors.background : AppColors.lightBackground;
  Color get colorSurface => _isDarkMode ? AppColors.surface : AppColors.lightSurface;
  Color get colorSurfaceVariant => _isDarkMode ? AppColors.surfaceVariant : AppColors.lightSurfaceVariant;
  Color get colorTextPrimary => _isDarkMode ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get colorTextSecondary => _isDarkMode ? AppColors.textSecondary : AppColors.lightTextSecondary;
}

ThemeData buildAppTheme({bool isDark = true}) {
  final bg = isDark ? AppColors.background : AppColors.lightBackground;
  final surface = isDark ? AppColors.surface : AppColors.lightSurface;
  final surfaceVariant = isDark ? AppColors.surfaceVariant : AppColors.lightSurfaceVariant;
  final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  final textSecondary = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
  final dividerColor = isDark ? const Color(0xFF3A3024) : const Color(0xFFE6DDCC);

  final base = ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: AppColors.accent,
      surface: surface,
    ),
    scaffoldBackgroundColor: bg,
    textTheme: GoogleFonts.interTextTheme(isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme),
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: bg,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.accent : textSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? AppColors.accent : textSecondary);
      }),
    ),
    listTileTheme: ListTileThemeData(textColor: textPrimary, iconColor: textSecondary),
    dividerTheme: DividerThemeData(color: dividerColor, thickness: 1, space: 1),
    tabBarTheme: TabBarThemeData(
      labelColor: textPrimary,
      unselectedLabelColor: textSecondary,
      indicatorColor: textPrimary,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.accent),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.accent;
        return Colors.transparent;
      }),
      checkColor: const WidgetStatePropertyAll(Colors.black),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: surfaceVariant,
      selectedColor: AppColors.accent,
      labelStyle: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
      side: BorderSide.none,
    ),
  );
}
