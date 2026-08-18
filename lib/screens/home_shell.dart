import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/localization_context.dart';
import '../providers/settings_provider.dart';
import 'books_screen.dart';
import 'manga_screen.dart';
import 'explorer_screen.dart';
import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final Set<int> _visited = {_index};

  static const _screens = [
    BooksScreen(),
    MangaScreen(),
    ExplorerScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    context.watch<SettingsProvider>();
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _screens.length; i++)
            _visited.contains(i) ? _screens[i] : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          _visited.add(i);
        }),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.menu_book_outlined), label: context.tr('nav.books')),
          NavigationDestination(icon: const Icon(Icons.auto_stories_outlined), label: context.tr('nav.manga')),
          NavigationDestination(icon: const Icon(Icons.search), label: context.tr('nav.explore')),
          NavigationDestination(icon: const Icon(Icons.person_outline), label: context.tr('nav.profile')),
        ],
      ),
    );
  }
}
