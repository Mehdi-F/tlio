import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/localization_context.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/book_service.dart';
import '../services/manga_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings.title'))),
      body: ListView(
        children: [
          _buildSection(context.tr('settings.appearance'), [
            _buildThemeOption(context),
          ]),
          _buildSection(context.tr('settings.general'), [
            _buildLanguageOption(context),
          ]),
          _buildSection(context.tr('settings.data'), [
            _buildCacheTile(context),
          ]),
          _buildSection(context.tr('settings.account'), [
            _buildLogoutTile(context),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildThemeOption(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('settings.theme'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildThemeChip(context, AppThemeMode.light, context.tr('settings.themeLight'), settings.themeMode == AppThemeMode.light),
                  const SizedBox(width: 8),
                  _buildThemeChip(context, AppThemeMode.dark, context.tr('settings.themeDark'), settings.themeMode == AppThemeMode.dark),
                  const SizedBox(width: 8),
                  _buildThemeChip(context, AppThemeMode.auto, context.tr('settings.themeAuto'), settings.themeMode == AppThemeMode.auto),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeChip(BuildContext context, AppThemeMode mode, String label, bool selected) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => context.read<SettingsProvider>().setThemeMode(mode),
      selectedColor: AppColors.accent,
      labelStyle: TextStyle(
        color: selected ? Colors.black : AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: AppColors.surfaceVariant,
      side: BorderSide.none,
    );
  }

  Widget _buildLanguageOption(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('settings.language'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: settings.language,
              items: [
                DropdownMenuItem(value: 'fr', child: Text(context.tr('settings.languageFrench'))),
                DropdownMenuItem(value: 'en', child: Text(context.tr('settings.languageEnglish'))),
              ],
              onChanged: (value) {
                if (value != null) {
                  context.read<SettingsProvider>().setLanguage(value);
                }
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheTile(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(context.tr('settings.clearCache'), style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(context.tr('settings.clearCacheDesc')),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        contentPadding: EdgeInsets.zero,
        onTap: () => _showClearCacheDialog(context),
      ),
    );
  }

  Widget _buildLogoutTile(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(context.tr('settings.logout'), style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
        contentPadding: EdgeInsets.zero,
        onTap: () => _showLogoutDialog(context),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(context.tr('settings.clearCacheConfirm')),
        content: Text(context.tr('settings.clearCacheConfirmDesc')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('common.cancel'))),
          TextButton(
            onPressed: () {
              context.read<BookService>().clearCache();
              context.read<MangaService>().clearCache();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.tr('settings.cacheClear')), duration: const Duration(seconds: 2)),
              );
            },
            child: Text(context.tr('common.delete')),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(context.tr('settings.logoutConfirm')),
        content: Text(context.tr('settings.logoutDesc')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('common.cancel'))),
          TextButton(
            onPressed: () {
              context.read<AuthProvider>().signOut();
              Navigator.pop(context);
            },
            child: Text(context.tr('settings.logout'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
