import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/localization_context.dart';
import '../models/library_item.dart';
import '../models/manga_models.dart';
import '../providers/auth_provider.dart';
import '../services/library_service.dart';
import '../services/manga_service.dart';
import '../theme/app_theme.dart';
import '../widgets/detail_banner.dart';
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
  MangaDetails? _details;
  bool _loadError = false;
  Future<LibraryItem?>? _addFuture;

  @override
  void initState() {
    super.initState();
    _libraryItem = widget.libraryItem;
    _load();
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
    foregroundColor: Colors.white,
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
                const Text('Impossible de charger ce titre.', style: TextStyle(color: AppColors.textSecondary)),
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
            DetailBanner(coverUrl: details.coverUrl, title: details.title),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(details.description, style: const TextStyle(fontSize: 14)),
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
                      final volumesRead = item?.volumesRead ?? 0;
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
                                    ? () => _toggleVolume(volumesRead, false)
                                    : null,
                                child: const Text('-1'),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                onPressed: () => _toggleVolume(volumesRead + 1, true),
                                child: const Text('+1'),
                              ),
                            ],
                          ),
                        ],
                      );
                    }),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: item == null ? _ensureAdded : null,
                    child: Text(item == null ? context.tr('detail.addToLibrary') : context.tr('common.done')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
