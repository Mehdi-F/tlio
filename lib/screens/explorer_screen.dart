import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/localization_context.dart';
import '../models/book_models.dart';
import '../models/manga_models.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../services/book_service.dart';
import '../services/library_service.dart';
import '../services/manga_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_route.dart';
import '../widgets/media_tile.dart';
import 'book_detail_screen.dart';
import 'manga_detail_screen.dart';

enum _ExplorerMode { books, manga }

const _bookCategories = [
  ('explorer.categoryComics', 'Comics & Graphic Novels'),
  ('explorer.categoryFiction', 'Fiction'),
  ('explorer.categoryFantasy', 'Fantasy'),
  ('explorer.categoryThriller', 'Thrillers'),
  ('explorer.categoryYoung', 'Juvenile Fiction'),
];

class ExplorerScreen extends StatefulWidget {
  const ExplorerScreen({super.key});

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  _ExplorerMode _mode = _ExplorerMode.books;
  final _controller = TextEditingController();
  List<BookSearchResult> _bookResults = [];
  List<MangaSearchResult> _mangaResults = [];
  bool _loading = false;
  bool _showDiscover = true;
  bool _error = false;
  Timer? _debounce;
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _ExplorerMode.values.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _showDiscover = value.trim().isEmpty);
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _bookResults = [];
        _mangaResults = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search([String? query]) async {
    final q = (query ?? _controller.text).trim();
    if (q.isEmpty) return;
    final token = ++_searchToken;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      if (_mode == _ExplorerMode.books) {
        final results = await context.read<BookService>().search(q);
        if (!mounted || token != _searchToken) return;
        setState(() => _bookResults = results);
      } else {
        final results = await context.read<MangaService>().search(q);
        if (!mounted || token != _searchToken) return;
        setState(() => _mangaResults = results);
      }
    } catch (_) {
      if (!mounted || token != _searchToken) return;
      setState(() => _error = true);
    } finally {
      if (mounted && token == _searchToken) setState(() => _loading = false);
    }
  }

  bool _alreadyInLibrary(String type, String sourceId) {
    return context.read<LibraryProvider>().items.any(
      (i) => i.type == type && i.sourceId == sourceId,
    );
  }

  Future<void> _addBook(BookSearchResult result) async {
    final uid = context.read<AuthProvider>().user!.uid;
    await context.read<LibraryService>().addToLibrary(
      uid: uid,
      sourceId: result.id,
      type: 'book',
      source: 'googlebooks',
    );
  }

  Future<void> _addManga(MangaSearchResult result) async {
    final uid = context.read<AuthProvider>().user!.uid;
    await context.read<LibraryService>().addToLibrary(
      uid: uid,
      sourceId: '${result.id}',
      type: 'manga',
      source: 'anilist',
      volumesTotal: result.volumes,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Nothing else in this screen subscribes to LibraryProvider — without
    // this, _alreadyInLibrary's context.read never triggers a rebuild after
    // adding, so the + icon never flips to a checkmark even though the
    // Firestore write succeeded. Looks completely dead no matter how many
    // times it's tapped.
    context.watch<LibraryProvider>();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          onChanged: _onQueryChanged,
          onSubmitted: (v) {
            _debounce?.cancel();
            _search(v);
          },
          decoration: InputDecoration(
            hintText: _mode == _ExplorerMode.books
                ? context.tr('explorer.searchBooks')
                : context.tr('explorer.searchManga'),
            border: InputBorder.none,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          onTap: (i) => setState(() => _mode = _ExplorerMode.values[i]),
          tabs: [
            Tab(text: context.tr('explorer.toggleBooks')),
            Tab(text: context.tr('explorer.toggleManga')),
          ],
        ),
      ),
      body: _showDiscover ? _buildDiscover(context) : _buildResults(context),
    );
  }

  Widget _buildDiscover(BuildContext context) {
    if (_mode == _ExplorerMode.books) {
      return ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          for (final (labelKey, subject) in _bookCategories)
            _BookCategoryRow(
              title: context.tr(labelKey),
              subject: subject,
              alreadyInLibrary: _alreadyInLibrary,
              onAdd: _addBook,
            ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        _MangaCategoryRow(
          title: context.tr('explorer.mangaTrending'),
          sort: 'TRENDING_DESC',
          alreadyInLibrary: _alreadyInLibrary,
          onAdd: _addManga,
        ),
        _MangaCategoryRow(
          title: context.tr('explorer.mangaPopular'),
          sort: 'POPULARITY_DESC',
          alreadyInLibrary: _alreadyInLibrary,
          onAdd: _addManga,
        ),
      ],
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error) {
      return _EmptyState(icon: Icons.wifi_off, message: context.tr('explorer.searchFailed'));
    }
    if (_mode == _ExplorerMode.books) {
      if (_bookResults.isEmpty) {
        return _EmptyState(icon: Icons.search_off, message: context.tr('explorer.noResults'));
      }
      return ListView.builder(
        itemCount: _bookResults.length,
        itemBuilder: (context, i) {
          final r = _bookResults[i];
          final inLibrary = _alreadyInLibrary('book', r.id);
          return MediaTile(
            coverUrl: r.thumbnailUrl,
            title: r.title,
            subtitle: r.authors.join(', '),
            trailing: inLibrary
                ? const Icon(Icons.check_circle, color: AppColors.accent)
                : IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _addBook(r),
                  ),
            onTap: () => Navigator.of(context).push(
              appRoute(builder: (_) => BookDetailScreen.preview(id: r.id)),
            ),
          );
        },
      );
    }
    if (_mangaResults.isEmpty) {
      return _EmptyState(icon: Icons.search_off, message: context.tr('explorer.noResults'));
    }
    return ListView.builder(
      itemCount: _mangaResults.length,
      itemBuilder: (context, i) {
        final r = _mangaResults[i];
        final inLibrary = _alreadyInLibrary('manga', '${r.id}');
        return MediaTile(
          coverUrl: r.coverUrl,
          title: r.title,
          placeholderIcon: Icons.auto_stories,
          trailing: inLibrary
              ? const Icon(Icons.check_circle, color: AppColors.accent)
              : IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _addManga(r),
                ),
          onTap: () => Navigator.of(
            context,
          ).push(appRoute(builder: (_) => MangaDetailScreen.preview(id: r.id))),
        );
      },
    );
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

class _CategoryTile extends StatelessWidget {
  final String? imageUrl;
  final VoidCallback onTap;
  final bool inLibrary;
  final VoidCallback onAdd;
  final IconData placeholderIcon;

  const _CategoryTile({
    required this.imageUrl,
    required this.onTap,
    required this.inLibrary,
    required this.onAdd,
    this.placeholderIcon = Icons.menu_book,
  });

  Widget _placeholder() => Container(
        color: AppColors.surfaceVariant,
        alignment: Alignment.center,
        child: Icon(placeholderIcon, color: AppColors.textSecondary, size: 28),
      );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 100,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 100,
                height: 140,
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
            Positioned(
              right: 2,
              bottom: 2,
              child: GestureDetector(
                onTap: inLibrary ? null : onAdd,
                child: Container(
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    inLibrary ? Icons.check_circle : Icons.add_circle_outline,
                    color: inLibrary ? Colors.greenAccent : Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookCategoryRow extends StatefulWidget {
  final String title;
  final String subject;
  final bool Function(String type, String sourceId) alreadyInLibrary;
  final void Function(BookSearchResult) onAdd;

  const _BookCategoryRow({
    required this.title,
    required this.subject,
    required this.alreadyInLibrary,
    required this.onAdd,
  });

  @override
  State<_BookCategoryRow> createState() => _BookCategoryRowState();
}

class _BookCategoryRowState extends State<_BookCategoryRow> {
  late final Future<List<BookSearchResult>> _future =
      context.read<BookService>().discover(widget.subject);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BookSearchResult>>(
      future: _future,
      builder: (context, snapshot) {
        final items = snapshot.data;
        if (items == null || items.isEmpty) return const SizedBox.shrink();
        return _CategoryRowLayout(
          title: widget.title,
          count: items.length,
          tileBuilder: (i) {
            final r = items[i];
            return _CategoryTile(
              imageUrl: r.thumbnailUrl,
              inLibrary: widget.alreadyInLibrary('book', r.id),
              onAdd: () => widget.onAdd(r),
              onTap: () => Navigator.of(context).push(
                appRoute(builder: (_) => BookDetailScreen.preview(id: r.id)),
              ),
            );
          },
        );
      },
    );
  }
}

class _MangaCategoryRow extends StatefulWidget {
  final String title;
  final String sort;
  final bool Function(String type, String sourceId) alreadyInLibrary;
  final void Function(MangaSearchResult) onAdd;

  const _MangaCategoryRow({
    required this.title,
    required this.sort,
    required this.alreadyInLibrary,
    required this.onAdd,
  });

  @override
  State<_MangaCategoryRow> createState() => _MangaCategoryRowState();
}

class _MangaCategoryRowState extends State<_MangaCategoryRow> {
  late final Future<List<MangaSearchResult>> _future =
      context.read<MangaService>().discover(sort: widget.sort);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MangaSearchResult>>(
      future: _future,
      builder: (context, snapshot) {
        final items = snapshot.data;
        if (items == null || items.isEmpty) return const SizedBox.shrink();
        return _CategoryRowLayout(
          title: widget.title,
          count: items.length,
          tileBuilder: (i) {
            final r = items[i];
            return _CategoryTile(
              imageUrl: r.coverUrl,
              inLibrary: widget.alreadyInLibrary('manga', '${r.id}'),
              onAdd: () => widget.onAdd(r),
              onTap: () => Navigator.of(context).push(
                appRoute(builder: (_) => MangaDetailScreen.preview(id: r.id)),
              ),
              placeholderIcon: Icons.auto_stories,
            );
          },
        );
      },
    );
  }
}

class _CategoryRowLayout extends StatelessWidget {
  final String title;
  final int count;
  final Widget Function(int index) tileBuilder;

  const _CategoryRowLayout({
    required this.title,
    required this.count,
    required this.tileBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: count,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: tileBuilder(index),
            ),
          ),
        ),
      ],
    );
  }
}
