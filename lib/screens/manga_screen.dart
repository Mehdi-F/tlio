import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/constants.dart';
import '../l10n/localization_context.dart';
import '../models/library_item.dart';
import '../models/manga_models.dart';
import '../providers/library_provider.dart';
import '../services/manga_service.dart';
import '../theme/app_theme.dart';
import '../utils/concurrency.dart';
import '../widgets/app_page_route.dart';
import '../widgets/library_sort_sheet.dart';
import '../widgets/media_tile.dart';
import '../widgets/skeletons.dart';
import 'manga_detail_screen.dart';

class _HistoryEntry {
  final LibraryItem item;
  final int volume;
  final DateTime readAt;

  _HistoryEntry({required this.item, required this.volume, required this.readAt});
}

/// A manga is "finished" once volumesRead has caught up to its total volume
/// count. The stored item.volumesTotal is only ever set from whatever
/// AniList returned at add time — if that fetch hadn't resolved yet, it
/// stays null forever. Falling back to the live-resolved MangaDetails'
/// volumes catches that case, same rationale as books_screen's _isFinished.
bool _isFinished(LibraryItem item, int? liveTotal) {
  final total = item.volumesTotal ?? liveTotal;
  return total != null && (item.volumesRead ?? 0) >= total;
}

class MangaScreen extends StatefulWidget {
  const MangaScreen({super.key});

  @override
  State<MangaScreen> createState() => _MangaScreenState();
}

class _MangaScreenState extends State<MangaScreen> {
  static const _historyPageSize = 15;

  final Map<String, MangaDetails> _resolved = {};
  final Set<String> _settled = {};
  bool _showContent = false;
  List<LibraryItem> _lastRawItems = const [];
  List<LibraryItem> _lastItems = const [];

  bool _historyExpanded = false;
  int _historyVisibleCount = 0;
  bool _historyLoadingMore = false;
  LibrarySort _sort = LibrarySort.lastActivity;

  void _sortItems(List<LibraryItem> items) {
    switch (_sort) {
      case LibrarySort.lastActivity:
        items.sort((a, b) => (b.lastActivityAt ?? b.addedAt).compareTo(a.lastActivityAt ?? a.addedAt));
      case LibrarySort.lastAdded:
        items.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case LibrarySort.alphabetical:
        items.sort((a, b) => compareLibraryByTitle(
            _resolved[a.docId]?.title ?? a.sourceId, _resolved[b.docId]?.title ?? b.sourceId));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rawItems = context.watch<LibraryProvider>().items;
    if (!identical(rawItems, _lastRawItems)) {
      _lastRawItems = rawItems;
      _lastItems = rawItems.where((i) => i.type == 'manga').toList();
      _resolveAll(_lastItems);
    }
  }

  Future<void> _resolveAll(List<LibraryItem> items) async {
    final manga = context.read<MangaService>();
    final keys = items.map((i) => i.docId).toSet();
    _resolved.removeWhere((k, _) => !keys.contains(k));
    _settled.removeWhere((k) => !keys.contains(k));

    final all = forEachBounded(items, 8, (item) async {
      try {
        final details = await manga.getDetails(int.parse(item.sourceId));
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

  List<_HistoryEntry> _historySkeleton() {
    final entries = <_HistoryEntry>[];
    for (final item in _lastItems) {
      for (final e in item.volumeReadAt.entries) {
        final volume = int.tryParse(e.key);
        if (volume == null) continue;
        entries.add(_HistoryEntry(item: item, volume: volume, readAt: e.value));
      }
    }
    entries.sort((a, b) => b.readAt.compareTo(a.readAt));
    return entries;
  }

  Future<void> _loadMoreHistory() async {
    if (_historyLoadingMore) return;
    final skeleton = _historySkeleton();
    if (_historyVisibleCount >= skeleton.length) return;
    setState(() => _historyLoadingMore = true);
    final newCount = (_historyVisibleCount + _historyPageSize).clamp(0, skeleton.length);
    final manga = context.read<MangaService>();
    final needed = {
      for (final s in skeleton.sublist(_historyVisibleCount, newCount))
        if (!_resolved.containsKey(s.item.docId)) s.item.docId: s.item,
    }.values.toList();
    await forEachBounded(needed, 4, (item) async {
      try {
        final details = await manga.getDetails(int.parse(item.sourceId));
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
      appBar: AppBar(title: Text(context.tr('manga.title'))),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (!_showContent) return const MediaListSkeleton();
    final skeleton = _historySkeleton();
    final hasAnyHistory = skeleton.isNotEmpty;
    final hasMoreHistory = _historyVisibleCount < skeleton.length;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          children: [
            if (hasAnyHistory) _historyToggleRow(context),
            if (_historyExpanded && _historyLoadingMore) _historyLoaderRow(),
            if (_historyExpanded && !_historyLoadingMore && hasMoreHistory) _historyLoadMoreRow(context),
            if (_historyExpanded) ..._historyEntryWidgets(context, skeleton.take(_historyVisibleCount).toList()),
            ..._buildLibraryRows(context),
          ],
        ),
        if (_lastItems.isNotEmpty)
          Positioned(
            right: 16,
            bottom: 16,
            child: LibrarySortButton(onTap: () async {
              final result = await showLibrarySortSheet(context, _sort);
              if (result != null) setState(() => _sort = result);
            }),
          ),
      ],
    );
  }

  List<Widget> _buildLibraryRows(BuildContext context) {
    if (_lastItems.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(32),
          child: _EmptyState(icon: Icons.auto_stories_outlined, message: context.tr('manga.empty')),
        ),
      ];
    }
    final toRead = _lastItems
        .where((i) => !_isFinished(i, _resolved[i.docId]?.volumes))
        .toList();
    _sortItems(toRead);
    if (toRead.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(32),
          child: _EmptyState(icon: Icons.auto_stories_outlined, message: context.tr('manga.allCaughtUp')),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          context.tr('manga.toRead'),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      ...toRead.map((item) {
        final details = _resolved[item.docId];
        final total = item.volumesTotal ?? details?.volumes;
        return MediaTile(
          coverUrl: details?.coverUrl,
          title: details?.title ?? item.sourceId,
          subtitle: total != null
              ? '${item.volumesRead ?? 0}/$total ${context.tr('manga.volumesProgress')}'
              : null,
          placeholderIcon: Icons.auto_stories,
          onTap: () => Navigator.of(context).push(appRoute(builder: (_) => MangaDetailScreen(libraryItem: item))),
        );
      }),
    ];
  }

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
              context.tr(_historyExpanded ? 'manga.hideHistory' : 'manga.showHistory'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
            Icon(_historyExpanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _historyLoadMoreRow(BuildContext context) {
    return Center(child: TextButton(onPressed: _loadMoreHistory, child: Text(context.tr('common.loadMore'))));
  }

  Widget _historyLoaderRow() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      );

  List<Widget> _historyEntryWidgets(BuildContext context, List<_HistoryEntry> entries) {
    return entries.map((e) {
      final details = _resolved[e.item.docId];
      return MediaTile(
        coverUrl: details?.coverUrl,
        title: details?.title ?? e.item.sourceId,
        subtitle: 'Tome ${e.volume}',
        placeholderIcon: Icons.auto_stories,
        dimmed: true,
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
