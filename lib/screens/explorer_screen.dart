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
import 'book_detail_screen.dart';
import 'manga_detail_screen.dart';

enum _ExplorerMode { books, manga }

class ExplorerScreen extends StatefulWidget {
  const ExplorerScreen({super.key});

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  _ExplorerMode _mode = _ExplorerMode.books;
  final _controller = TextEditingController();
  List<BookSearchResult> _bookResults = [];
  List<MangaSearchResult> _mangaResults = [];
  bool _loading = false;
  bool _error = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      if (_mode == _ExplorerMode.books) {
        final results = await context.read<BookService>().search(query);
        if (mounted) setState(() => _bookResults = results);
      } else {
        final results = await context.read<MangaService>().search(query);
        if (mounted) setState(() => _mangaResults = results);
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
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
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            hintText: _mode == _ExplorerMode.books
                ? context.tr('explorer.searchBooks')
                : context.tr('explorer.searchManga'),
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _search),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<_ExplorerMode>(
              segments: [
                ButtonSegment(
                  value: _ExplorerMode.books,
                  label: Text(context.tr('explorer.toggleBooks')),
                ),
                ButtonSegment(
                  value: _ExplorerMode.manga,
                  label: Text(context.tr('explorer.toggleManga')),
                ),
              ],
              selected: {_mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
          Expanded(child: _buildResults(context)),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error) {
      return Center(
        child: Text(
          context.tr('explorer.searchFailed'),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    if (_mode == _ExplorerMode.books) {
      if (_bookResults.isEmpty) {
        return Center(
          child: Text(
            context.tr('explorer.noResults'),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        );
      }
      return ListView.builder(
        itemCount: _bookResults.length,
        itemBuilder: (context, i) {
          final r = _bookResults[i];
          final inLibrary = _alreadyInLibrary('book', r.id);
          return ListTile(
            leading: SizedBox(
              width: 40,
              height: 56,
              child: r.thumbnailUrl != null
                  ? CachedNetworkImage(
                      imageUrl: r.thumbnailUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(color: AppColors.surfaceVariant),
            ),
            title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              r.authors.join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
      return Center(
        child: Text(
          context.tr('explorer.noResults'),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.builder(
      itemCount: _mangaResults.length,
      itemBuilder: (context, i) {
        final r = _mangaResults[i];
        final inLibrary = _alreadyInLibrary('manga', '${r.id}');
        return ListTile(
          leading: SizedBox(
            width: 40,
            height: 56,
            child: r.coverUrl != null
                ? CachedNetworkImage(imageUrl: r.coverUrl!, fit: BoxFit.cover)
                : Container(color: AppColors.surfaceVariant),
          ),
          title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
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
