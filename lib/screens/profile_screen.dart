import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/localization_context.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final user = context.watch<AuthProvider>().user;
    final books = library.items.where((i) => i.type == 'book').length;
    final comics = library.items.where((i) => i.type == 'comic').length;
    final manga = library.items.where((i) => i.type == 'manga').length;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile.title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user?.displayName != null)
            Text(user!.displayName!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatColumn(value: books, label: context.tr('profile.booksRead')),
              _StatColumn(value: comics, label: context.tr('profile.comicsRead')),
              _StatColumn(value: manga, label: context.tr('profile.mangaRead')),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => context.read<AuthProvider>().signOut(),
            child: Text(context.tr('profile.signOut')),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final int value;
  final String label;

  const _StatColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ],
    );
  }
}
