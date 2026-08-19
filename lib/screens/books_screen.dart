import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/constants.dart';
import '../l10n/localization_context.dart';
import '../models/book_models.dart';
import '../models/library_item.dart';
import '../providers/library_provider.dart';
import '../services/book_service.dart';
import '../theme/app_theme.dart';
import '../utils/concurrency.dart';
import '../widgets/app_page_route.dart';
import '../widgets/media_tile.dart';
import '../widgets/skeletons.dart';
import 'book_detail_screen.dart';

enum _Filter { all, books, comics }

/// A book/comic is "finished" once pagesRead has caught up to its total
/// page count. The stored item.pagesTotal is only ever set from whatever
/// Google Books returned at the moment the title was added — if that
/// fetch hadn't resolved yet, it stays null forever. Falling back to the
/// live-resolved BookDetails' pageCount catches that case instead of
/// leaving a fully-read title stuck in "in progress" forever.
bool _isFinished(LibraryItem item, int? liveTotal) {
  final total = item.pagesTotal ?? liveTotal;
  return total != null && (item.pagesRead ?? 0) >= total;
}

bool _isStarted(LibraryItem item) => (item.pagesRead ?? 0) > 0;

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen>
    with SingleTickerProviderStateMixin {
  static const _historyPageSize = 15;

  late final TabController _tabController;
  _Filter _filter = _Filter.all;
  final Map<String, BookDetails> _resolved = {};
  final Set<String> _settled = {};
  bool _showContent = false;
  List<LibraryItem> _lastRawItems = const [];
  List<LibraryItem> _lastItems = const [];

  bool _historyExpanded = false;
  int _historyVisibleCount = 0;
  bool _historyLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _Filter.values.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rawItems = context.watch<LibraryProvider>().items;
    if (!identical(rawItems, _lastRawItems)) {
      _lastRawItems = rawItems;
      _lastItems = rawItems
          .where((i) => i.type == 'book' || i.type == 'comic')
          .toList();
      _resolveAll(_lastItems);
    }
  }

  Future<void> _resolveAll(List<LibraryItem> items) async {
    final book = context.read<BookService>();
    final keys = items.map((i) => i.docId).toSet();
    _resolved.removeWhere((k, _) => !keys.contains(k));
    _settled.removeWhere((k) => !keys.contains(k));

    final all = forEachBounded(items, 8, (item) async {
      try {
        final details = await book.getDetails(item.sourceId);
        if (mounted) {
          setState(() {
            _resolved[item.docId] = details;
            _settled.add(item.docId);
          });
        }
      } catch (_) {
        if (mounted) setState(() => _settled.add(item.docId));
      }
    });
    await all.timeout(AppConstants.initialLoadTimeout, onTimeout: () {});
    if (mounted) setState(() => _showContent = true);
  }

  List<LibraryItem> get _filteredItems {
    switch (_filter) {
      case _Filter.all:
        return _lastItems;
      case _Filter.books:
        return _lastItems.where((i) => i.type == 'book').toList();
      case _Filter.comics:
        return _lastItems.where((i) => i.type == 'comic').toList();
    }
  }

  List<LibraryItem> get _finishedItems =>
      _filteredItems.where((i) => _isFinished(i, _resolved[i.docId]?.pageCount)).toList()
        ..sort((a, b) =>
            (b.lastActivityAt ?? b.addedAt).compareTo(a.lastActivityAt ?? a.addedAt));

  Future<void> _loadMoreHistory() async {
    if (_historyLoadingMore) return;
    final finished = _finishedItems;
    if (_historyVisibleCount >= finished.length) return;
    setState(() => _historyLoadingMore = true);
    final newCount = (_historyVisibleCount + _historyPageSize).clamp(0, finished.length);
    final book = context.read<BookService>();
    final needed = finished
        .sublist(_historyVisibleCount, newCount)
        .where((i) => !_resolved.containsKey(i.docId))
        .toList();
    await forEachBounded(needed, 4, (item) async {
      try {
        final details = await book.getDetails(item.sourceId);
        if (mounted) setState(() => _resolved[item.docId] = details);
      } catch (_) {}
    });
    if (mounted) {
      setState(() {
        _historyVisibleCount = newCount;
        _historyLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('books.title')),
        bottom: TabBar(
          controller: _tabController,
          onTap: (i) => setState(() {
            _filter = _Filter.values[i];
            _historyVisibleCount = 0;
            _historyExpanded = false;
          }),
          tabs: [
            Tab(text: context.tr('books.filterAll')),
            Tab(text: context.tr('books.filterBooks')),
            Tab(text: context.tr('books.filterComics')),
          ],
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (!_showContent) return const MediaListSkeleton();
    final items = _filteredItems;
    if (items.isEmpty) {
      return _EmptyState(icon: Icons.menu_book_outlined, message: context.tr('books.empty'));
    }

    final inProgress = items
        .where((i) => _isStarted(i) && !_isFinished(i, _resolved[i.docId]?.pageCount))
        .toList()
      ..sort((a, b) =>
          (b.lastActivityAt ?? b.addedAt).compareTo(a.lastActivityAt ?? a.addedAt));
    final toRead = items.where((i) => !_isStarted(i)).toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final finished = _finishedItems;
    final hasAnyFinished = finished.isNotEmpty;
    final hasMoreHistory = _historyVisibleCount < finished.length;
    final history = _historyExpanded ? finished.take(_historyVisibleCount).toList() : const <LibraryItem>[];

    if (inProgress.isEmpty && toRead.isEmpty && !hasAnyFinished) {
      return _EmptyState(icon: Icons.menu_book_outlined, message: context.tr('books.allCaughtUp'));
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      children: [
        if (hasAnyFinished) _historyToggleRow(context),
        if (_historyExpanded && _historyLoadingMore) _historyLoaderRow(),
        if (_historyExpanded && !_historyLoadingMore && hasMoreHistory) _historyLoadMoreRow(context),
        if (history.isNotEmpty) ..._itemTiles(context, history, dimmed: true),
        if (inProgress.isNotEmpty) ..._section(context, context.tr('books.inProgress'), inProgress),
        if (toRead.isNotEmpty) ..._section(context, context.tr('books.toRead'), toRead),
      ],
    );
  }

  List<Widget> _section(BuildContext context, String label, List<LibraryItem> items) {
    return [_sectionHeader(label), ..._itemTiles(context, items)];
  }

  Widget _sectionHeader(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _historyToggleRow(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final expanding = !_historyExpanded;
        setState(() => _historyExpanded = expanding);
        if (expanding && _historyVisibleCount == 0) _loadMoreHistory();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.tr(_historyExpanded ? 'books.hideHistory' : 'books.showHistory'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            Icon(
              _historyExpanded ? Icons.expand_less : Icons.expand_more,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyLoadMoreRow(BuildContext context) {
    return Center(
      child: TextButton(onPressed: _loadMoreHistory, child: Text(context.tr('common.loadMore'))),
    );
  }

  Widget _historyLoaderRow() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );

  List<Widget> _itemTiles(BuildContext context, List<LibraryItem> items, {bool dimmed = false}) {
    return items.map((item) {
      final details = _resolved[item.docId];
      final total = item.pagesTotal ?? details?.pageCount;
      return MediaTile(
        coverUrl: details?.thumbnailUrl,
        title: details?.title ?? item.sourceId,
        subtitle: item.type == 'book' && total != null
            ? '${item.pagesRead ?? 0}/$total ${context.tr('books.pagesProgress')}'
            : null,
        dimmed: dimmed,
        onTap: () => Navigator.of(context)
            .push(appRoute(builder: (_) => BookDetailScreen(libraryItem: item))),
      );
    }).toList();
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 40),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
