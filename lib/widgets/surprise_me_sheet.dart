import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/localization_context.dart';
import '../models/library_item.dart';
import '../providers/library_provider.dart';
import '../screens/book_detail_screen.dart';
import '../screens/manga_detail_screen.dart';
import '../services/book_service.dart';
import '../services/manga_service.dart';
import '../theme/app_theme.dart';
import '../utils/concurrency.dart';
import 'app_page_route.dart';

class _Candidate {
  final LibraryItem item;
  final String? title;
  final String? coverUrl;

  _Candidate({required this.item, required this.title, required this.coverUrl});
}

void showSurpriseMeSheet(BuildContext context) {
  final items = context.read<LibraryProvider>().items;
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _SurpriseSheet(items: items, book: context.read<BookService>(), manga: context.read<MangaService>()),
  );
}

class _SurpriseSheet extends StatefulWidget {
  final List<LibraryItem> items;
  final BookService book;
  final MangaService manga;

  const _SurpriseSheet({required this.items, required this.book, required this.manga});

  @override
  State<_SurpriseSheet> createState() => _SurpriseSheetState();
}

class _SurpriseSheetState extends State<_SurpriseSheet> {
  List<_Candidate> _pool = [];
  _Candidate? _pick;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _buildPool();
  }

  /// item.status never actually transitions to "completed" anywhere in the
  /// app, so the pool has to be built from each title's real progress
  /// (pagesRead/volumesRead vs the resolved total) instead of trusting that
  /// field — otherwise already-finished titles keep showing up here.
  Future<void> _buildPool() async {
    final candidates = <_Candidate>[];
    await forEachBounded(widget.items, 8, (item) async {
      try {
        if (item.type == 'manga') {
          final details = await widget.manga.getDetails(int.parse(item.sourceId));
          final total = item.volumesTotal ?? details.volumes;
          final finished = total != null && (item.volumesRead ?? 0) >= total;
          if (!finished) candidates.add(_Candidate(item: item, title: details.title, coverUrl: details.coverUrl));
        } else {
          final details = await widget.book.getDetails(item.sourceId);
          final total = item.pagesTotal ?? details.pageCount;
          final finished = total != null && (item.pagesRead ?? 0) >= total;
          if (!finished) candidates.add(_Candidate(item: item, title: details.title, coverUrl: details.thumbnailUrl));
        }
      } catch (_) {}
    });
    if (!mounted) return;
    final pool = [...candidates, ...candidates.where((c) => c.item.favorite)];
    setState(() {
      _pool = pool;
      _pick = pool.isEmpty ? null : pool[Random().nextInt(pool.length)];
      _loading = false;
    });
  }

  void _reroll() {
    if (_pool.length <= 1) return;
    final current = _pick;
    final candidates = current == null ? _pool : _pool.where((c) => c.item.docId != current.item.docId).toList();
    setState(() => _pick = candidates[Random().nextInt(candidates.length)]);
  }

  void _open() {
    final pick = _pick;
    if (pick == null) return;
    Navigator.of(context).pop();
    Navigator.of(context).push(appRoute(
      builder: (_) =>
          pick.item.type == 'manga' ? MangaDetailScreen(libraryItem: pick.item) : BookDetailScreen(libraryItem: pick.item),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pick = _pick;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('surprise.title'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 20),
            if (_loading)
              const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()))
            else if (pick == null)
              SizedBox(
                height: 120,
                child: Center(
                  child: Text(context.tr('surprise.empty'), style: const TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else ...[
              SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: pick.coverUrl != null
                      ? CachedNetworkImage(imageUrl: pick.coverUrl!, fit: BoxFit.cover)
                      : Container(
                          color: AppColors.surfaceVariant,
                          alignment: Alignment.center,
                          child: Icon(
                            pick.item.type == 'manga' ? Icons.auto_stories : Icons.menu_book,
                            color: AppColors.textSecondary,
                            size: 48,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                pick.title ?? context.tr('surprise.notFound'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: pick == null ? null : _open, child: Text(context.tr('surprise.open'))),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(onPressed: pick == null || _loading ? null : _reroll, child: Text(context.tr('surprise.reroll'))),
            ),
          ],
        ),
      ),
    );
  }
}
