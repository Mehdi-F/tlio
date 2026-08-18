import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/localization_context.dart';
import '../models/book_models.dart';
import '../models/library_item.dart';
import '../providers/auth_provider.dart';
import '../services/book_service.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../widgets/skeletons.dart';

class BookDetailScreen extends StatefulWidget {
  final LibraryItem? libraryItem;
  final String? previewId;
  final String previewType;

  const BookDetailScreen({super.key, required LibraryItem libraryItem})
    : libraryItem = libraryItem,
      previewId = null,
      previewType = 'book';

  const BookDetailScreen.preview({
    super.key,
    required String id,
    String type = 'book',
  }) : libraryItem = null,
       previewId = id,
       previewType = type;

  String get sourceId => libraryItem?.sourceId ?? previewId!;
  String get type => libraryItem?.type ?? previewType;

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  LibraryItem? _libraryItem;
  BookDetails? _details;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _libraryItem = widget.libraryItem;
    _load();
  }

  Future<void> _load() async {
    final book = context.read<BookService>();
    try {
      final details = await book.getDetails(widget.sourceId);
      if (mounted) setState(() => _details = details);
    } catch (_) {
      if (mounted) setState(() => _loadError = true);
    }
  }

  Future<LibraryItem?> _ensureAdded() async {
    final current = _libraryItem;
    if (current != null) return current;
    final uid = context.read<AuthProvider>().user!.uid;
    final item = await context.read<LibraryService>().addToLibrary(
      uid: uid,
      sourceId: widget.sourceId,
      type: widget.type,
      source: 'googlebooks',
      pagesTotal: _details?.pageCount,
    );
    if (mounted) setState(() => _libraryItem = item);
    return item;
  }

  Future<void> _updatePages(int pagesRead) async {
    final item = await _ensureAdded();
    if (item == null) return;
    final uid = context.read<AuthProvider>().user!.uid;
    await context.read<LibraryService>().updateBookProgress(
      uid: uid,
      docId: item.docId,
      pagesRead: pagesRead,
    );
    if (mounted)
      setState(() => _libraryItem = item.copyWith(pagesRead: pagesRead));
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    if (details == null) {
      if (_loadError) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Impossible de charger ce titre.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Réessayer')),
              ],
            ),
          ),
        );
      }
      return const Scaffold(body: DetailScreenSkeleton());
    }

    final item = _libraryItem;
    final pageCount = details.pageCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          details.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: SizedBox(
              width: 140,
              height: 200,
              child: details.thumbnailUrl != null
                  ? CachedNetworkImage(
                      imageUrl: details.thumbnailUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(color: AppColors.surfaceVariant),
            ),
          ),
          const SizedBox(height: 16),
          if (details.authors.isNotEmpty)
            Text(
              '${context.tr('detail.by')} ${details.authors.join(', ')}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          const SizedBox(height: 16),
          Text(details.description, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 24),
          if (pageCount != null) ...[
            Text(
              '${item?.pagesRead ?? 0}/$pageCount ${context.tr('books.pagesProgress')}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Slider(
              value: (item?.pagesRead ?? 0).clamp(0, pageCount).toDouble(),
              min: 0,
              max: pageCount.toDouble(),
              divisions: pageCount > 0 ? pageCount : 1,
              onChanged: (v) => _updatePages(v.round()),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: item == null ? _ensureAdded : null,
            child: Text(
              item == null
                  ? context.tr('detail.addToLibrary')
                  : context.tr('common.done'),
            ),
          ),
        ],
      ),
    );
  }
}
