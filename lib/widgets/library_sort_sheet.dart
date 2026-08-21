import 'package:flutter/material.dart';
import '../l10n/localization_context.dart';
import '../theme/app_theme.dart';

enum LibrarySort { lastActivity, lastAdded, alphabetical }

String librarySortLabel(BuildContext context, LibrarySort sort) {
  switch (sort) {
    case LibrarySort.lastActivity:
      return context.tr('sort.lastActivity');
    case LibrarySort.lastAdded:
      return context.tr('sort.lastAdded');
    case LibrarySort.alphabetical:
      return context.tr('sort.alphabetical');
  }
}

Future<LibrarySort?> showLibrarySortSheet(BuildContext context, LibrarySort initialSort) {
  return showModalBottomSheet<LibrarySort>(
    context: context,
    backgroundColor: context.colorSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _LibrarySortSheet(initialSort: initialSort),
  );
}

class _LibrarySortSheet extends StatefulWidget {
  final LibrarySort initialSort;

  const _LibrarySortSheet({required this.initialSort});

  @override
  State<_LibrarySortSheet> createState() => _LibrarySortSheetState();
}

class _LibrarySortSheetState extends State<_LibrarySortSheet> {
  late LibrarySort _sort = widget.initialSort;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('common.sortBy'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 12),
            for (final option in LibrarySort.values)
              RadioListTile<LibrarySort>(
                value: option,
                groupValue: _sort,
                onChanged: (v) => setState(() => _sort = v as LibrarySort),
                title: Text(librarySortLabel(context, option)),
                activeColor: AppColors.accent,
                contentPadding: EdgeInsets.zero,
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_sort),
                child: Text(context.tr('common.apply').toUpperCase()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating "Trier" pill, sits above the scrollable content rather than
/// occupying its own row — same convention as Showtime's LibraryFilterButton.
class LibrarySortButton extends StatelessWidget {
  final VoidCallback onTap;

  const LibrarySortButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(24),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sort, color: Colors.black, size: 18),
              const SizedBox(width: 8),
              Text(context.tr('common.sortBy'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

int compareLibraryByTitle(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
