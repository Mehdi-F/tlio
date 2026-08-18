import 'package:cached_network_image/cached_network_image.dart';
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
import '../widgets/skeletons.dart';
import 'book_detail_screen.dart';

enum _Filter { all, books, comics }

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  _Filter _filter = _Filter.all;
  final Map<String, BookDetails> _resolved = {};
  final Set<String> _settled = {};
  bool _showContent = false;
  List<LibraryItem> _lastRawItems = const [];
  List<LibraryItem> _lastItems = const [];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('books.title')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SegmentedButton<_Filter>(
              segments: [
                ButtonSegment(
                  value: _Filter.all,
                  label: Text(context.tr('books.filterAll')),
                ),
                ButtonSegment(
                  value: _Filter.books,
                  label: Text(context.tr('books.filterBooks')),
                ),
                ButtonSegment(
                  value: _Filter.comics,
                  label: Text(context.tr('books.filterComics')),
                ),
              ],
              selected: {_filter},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_showContent) return const MediaListSkeleton();
    final items = _filteredItems;
    if (items.isEmpty) {
      return Center(
        child: Text(
          context.tr('books.empty'),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final details = _resolved[item.docId];
        return ListTile(
          leading: SizedBox(
            width: 44,
            height: 62,
            child: details?.thumbnailUrl != null
                ? CachedNetworkImage(
                    imageUrl: details!.thumbnailUrl!,
                    fit: BoxFit.cover,
                  )
                : Container(color: AppColors.surfaceVariant),
          ),
          title: Text(
            details?.title ?? item.sourceId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: item.type == 'book' && item.pagesTotal != null
              ? Text(
                  '${item.pagesRead ?? 0}/${item.pagesTotal} ${context.tr('books.pagesProgress')}',
                )
              : null,
          onTap: () => Navigator.of(
            context,
          ).push(appRoute(builder: (_) => BookDetailScreen(libraryItem: item))),
        );
      },
    );
  }
}
