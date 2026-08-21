import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/localization_context.dart';
import '../models/library_item.dart';
import '../models/manga_models.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../services/library_service.dart';
import '../services/manga_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_bar.dart';
import '../widgets/detail_banner.dart';
import '../widgets/expandable_text.dart';
import '../widgets/skeletons.dart';

class MangaDetailScreen extends StatefulWidget {
  final LibraryItem? libraryItem;
  final int? previewId;

  const MangaDetailScreen({super.key, required LibraryItem libraryItem})
      : libraryItem = libraryItem,
        previewId = null;

  const MangaDetailScreen.preview({super.key, required int id})
      : libraryItem = null,
        previewId = id;

  int get anilistId => libraryItem != null ? int.parse(libraryItem!.sourceId) : previewId!;

  @override
  State<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends State<MangaDetailScreen> {
  LibraryItem? _libraryItem;
  bool _favorite = false;
  MangaDetails? _details;
  bool _loadError = false;
  Future<LibraryItem?>? _addFuture;

  @override
  void initState() {
    super.initState();
    // Explorer's search/discover results always open via .preview (no
    // LibraryItem in hand), even for titles already in the library — without
    // this lookup the button always read "Ajouter" regardless of actual
    // state, since it only ever checked widget.libraryItem.
    _libraryItem = widget.libraryItem ?? _findExisting();
    _favorite = _libraryItem?.favorite ?? false;
    _load();
  }

  LibraryItem? _findExisting() {
    final items = context.read<LibraryProvider>().items;
    for (final i in items) {
      if (i.type == 'manga' && i.sourceId == '${widget.anilistId}') return i;
    }
    return null;
  }

  Future<void> _load() async {
    final manga = context.read<MangaService>();
    try {
      final details = await manga.getDetails(widget.anilistId);
      if (mounted) setState(() => _details = details);
    } catch (_) {
      if (mounted) setState(() => _loadError = true);
    }
  }

  Future<LibraryItem?> _ensureAdded() {
    final current = _libraryItem;
    if (current != null) return Future.value(current);
    return _addFuture ??= _doAdd();
  }

  Future<LibraryItem?> _doAdd() async {
    final uid = context.read<AuthProvider>().user!.uid;
    final item = await context.read<LibraryService>().addToLibrary(
          uid: uid,
          sourceId: '${widget.anilistId}',
          type: 'manga',
          source: 'anilist',
          volumesTotal: _details?.volumes,
        );
    if (mounted) setState(() => _libraryItem = item);
    return item;
  }

  Future<void> _remove() async {
    final item = _libraryItem;
    if (item == null) return;
    final uid = context.read<AuthProvider>().user!.uid;
    await context.read<LibraryService>().removeFromLibrary(uid: uid, docId: item.docId);
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _toggleFavorite() async {
    // Flip instantly, even if not added yet — same rationale as Showtime's
    // _toggleFavorite: awaiting _ensureAdded() first would make favoriting
    // a preview manga wait on a full addToLibrary round-trip before the
    // heart visually changed at all.
    final newValue = !_favorite;
    final previous = _favorite;
    setState(() => _favorite = newValue);
    final item = await _ensureAdded();
    if (item == null) {
      if (mounted) setState(() => _favorite = previous);
      return;
    }
    final uid = context.read<AuthProvider>().user!.uid;
    try {
      await context.read<LibraryService>().toggleFavorite(uid: uid, docId: item.docId, favorite: newValue);
      if (mounted) setState(() => _libraryItem = item.copyWith(favorite: newValue));
    } catch (_) {
      if (mounted) setState(() => _favorite = previous);
    }
  }

  Future<void> _toggleVolume(int volume, bool read) async {
    final item = await _ensureAdded();
    if (!mounted || item == null) return;
    final uid = context.read<AuthProvider>().user!.uid;
    final library = context.read<LibraryService>();
    await library.markVolumeRead(uid: uid, docId: item.docId, volume: volume, read: read);
    final newReadAt = Map<String, DateTime>.from(item.volumeReadAt);
    if (read) {
      newReadAt['$volume'] = DateTime.now();
    } else {
      newReadAt.remove('$volume');
    }
    final newCount = newReadAt.length;
    await library.updateVolumeProgress(uid: uid, docId: item.docId, volumesRead: newCount);
    if (mounted) setState(() => _libraryItem = item.copyWith(volumeReadAt: newReadAt, volumesRead: newCount));
  }

  AppBar _minimalAppBar() => AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
  );

  @override
  Widget build(BuildContext context) {
    final details = _details;
    if (details == null) {
      if (_loadError) {
        return Scaffold(
          appBar: _minimalAppBar(),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Impossible de charger ce titre.', style: TextStyle(color: context.colorTextSecondary)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Réessayer')),
              ],
            ),
          ),
        );
      }
      return Scaffold(appBar: _minimalAppBar(), body: const DetailScreenSkeleton());
    }

    final item = _libraryItem;
    final total = details.volumes;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DetailBanner(
              coverUrl: details.coverUrl,
              title: details.title,
              inLibrary: item != null,
              favorite: _favorite,
              onToggleFavorite: _toggleFavorite,
              onRemove: _remove,
              placeholderIcon: Icons.auto_stories,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExpandableText(text: details.description),
                  const SizedBox(height: 24),
                  if (total != null) ...[
                    Text('${item?.volumesRead ?? 0}/$total ${context.tr('manga.volumesProgress')}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(total, (i) {
                        final volume = i + 1;
                        final read = item?.volumeReadAt.containsKey('$volume') ?? false;
                        return FilterChip(
                          label: Text('$volume'),
                          selected: read,
                          onSelected: (v) => _toggleVolume(volume, v),
                        );
                      }),
                    ),
                  ] else
                    // AniList has no volume count for this title, so there's
                    // no fixed range to render chips for — an open-ended
                    // stepper lets progress still be tracked (and still
                    // feeds the same per-volume history as the chips).
                    Builder(builder: (context) {
                      // Derived from the actual volumeReadAt keys, not the
                      // cached item.volumesRead field — that field can drift
                      // from the map (e.g. a stale write), and picking the
                      // next volume off a drifted count re-writes a key that
                      // already exists, which is a silent no-op: the map's
                      // length doesn't change, so the button looks broken.
                      final volumeKeys = item?.volumeReadAt.keys
                              .map((k) => int.tryParse(k) ?? 0)
                              .toList() ??
                          [];
                      final volumesRead = volumeKeys.length;
                      final maxVolume = volumeKeys.isEmpty
                          ? 0
                          : volumeKeys.reduce((a, b) => a > b ? a : b);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$volumesRead ${context.tr('manga.volumesProgress')}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: volumesRead > 0
                                    ? () => _toggleVolume(maxVolume, false)
                                    : null,
                                child: const Text('-1'),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                onPressed: () => _toggleVolume(maxVolume + 1, true),
                                child: const Text('+1'),
                              ),
                            ],
                          ),
                        ],
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedSlide(
        offset: item == null ? Offset.zero : const Offset(0, 1),
        duration: const Duration(milliseconds: 300),
        child: AnimatedOpacity(
          opacity: item == null ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          child: AddBar(label: context.tr('detail.addToLibrary'), onTap: _ensureAdded),
        ),
      ),
    );
  }
}
