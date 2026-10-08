import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/localization_context.dart';
import '../models/book_models.dart';
import '../models/library_item.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../services/book_service.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_bar.dart';
import '../widgets/completion_celebration.dart';
import '../widgets/detail_banner.dart';
import '../widgets/expandable_text.dart';
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

class _BookDetailScreenState extends State<BookDetailScreen> with SingleTickerProviderStateMixin {
  late final CompletionCelebrator _celebrator;
  LibraryItem? _libraryItem;
  bool _favorite = false;
  BookDetails? _details;
  bool _loadError = false;
  Future<LibraryItem?>? _addFuture;
  final _pageController = TextEditingController();
  bool _pageControllerSeeded = false;

  @override
  void initState() {
    super.initState();
    // Created up front rather than lazily: a lazy first touch from dispose()
    // would build the ticker on a deactivated element and assert.
    _celebrator = CompletionCelebrator(vsync: this);
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
      if (i.type == widget.type && i.sourceId == widget.sourceId) return i;
    }
    return null;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _celebrator.dispose();
    super.dispose();
  }

  /// Only sets the field's initial text once — after that the field is the
  /// user's to edit, and _updatePages keeps it in sync on every change.
  void _seedPageController(int pagesRead) {
    if (_pageControllerSeeded) return;
    _pageControllerSeeded = true;
    _pageController.text = '$pagesRead';
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

  Future<LibraryItem?> _ensureAdded() {
    final current = _libraryItem;
    if (current != null) return Future.value(current);
    return _addFuture ??= _doAdd();
  }

  Future<LibraryItem?> _doAdd() async {
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
    // a preview book wait on a full addToLibrary round-trip before the
    // heart visually changed at all.
    //
    // uid/libraryService are captured before the await on purpose: reading
    // them via context *after* an await is what broke this — if the user
    // navigates away while _ensureAdded() is still in flight (e.g. taps
    // "Marquer comme terminé" then immediately backs out), the widget is
    // disposed by the time the await resolves, context.read throws, and
    // the actual Firestore write never happens — even though the item
    // looked added in the meantime.
    final newValue = !_favorite;
    final previous = _favorite;
    setState(() => _favorite = newValue);
    final uid = context.read<AuthProvider>().user!.uid;
    final libraryService = context.read<LibraryService>();
    final item = await _ensureAdded();
    if (item == null) {
      if (mounted) setState(() => _favorite = previous);
      return;
    }
    try {
      await libraryService.toggleFavorite(uid: uid, docId: item.docId, favorite: newValue);
      if (mounted) setState(() => _libraryItem = item.copyWith(favorite: newValue));
    } catch (_) {
      if (mounted) setState(() => _favorite = previous);
    }
  }

  Future<void> _updatePages(int pagesRead) async {
    final pageCount = _details?.pageCount;
    final clamped = pageCount != null ? pagesRead.clamp(0, pageCount) : pagesRead.clamp(0, 1 << 30);
    // Same fix as _toggleFavorite: capture these before the await so the
    // write still goes through even if the screen's been popped by the
    // time _ensureAdded() resolves.
    final uid = context.read<AuthProvider>().user!.uid;
    final libraryService = context.read<LibraryService>();
    final pagesBefore = _libraryItem?.pagesRead ?? 0;
    final item = await _ensureAdded();
    if (item == null) return;
    await libraryService.updateBookProgress(
      uid: uid,
      docId: item.docId,
      pagesRead: clamped,
    );
    if (mounted) {
      setState(() => _libraryItem = item.copyWith(pagesRead: clamped));
      _pageController.text = '$clamped';
      // Only on the step that crosses the last page — not when re-saving a
      // book that was already finished.
      if (pageCount != null && pagesBefore < pageCount && clamped >= pageCount) {
        _celebrator.play(
          context,
          label: context.tr('celebrate.readCompleted'),
          coverUrl: _details?.thumbnailUrl,
        );
      }
    }
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
                Text(
                  'Impossible de charger ce titre.',
                  style: TextStyle(color: context.colorTextSecondary),
                ),
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
    final pageCount = details.pageCount;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DetailBanner(
              coverUrl: details.thumbnailUrl,
              title: details.title,
              inLibrary: item != null,
              favorite: _favorite,
              onToggleFavorite: _toggleFavorite,
              onRemove: _remove,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (details.authors.isNotEmpty) ...[
                    Text(
                      '${context.tr('detail.by')} ${details.authors.join(', ')}',
                      style: TextStyle(color: context.colorTextSecondary),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ExpandableText(text: details.description),
                  const SizedBox(height: 24),
                  if (pageCount != null) ...[
                    Builder(builder: (context) {
                      _seedPageController(item?.pagesRead ?? 0);
                      final pagesRead = item?.pagesRead ?? 0;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$pagesRead/$pageCount ${context.tr('books.pagesProgress')}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _PageStepButton(label: '-10', onTap: () => _updatePages(pagesRead - 10)),
                              const SizedBox(width: 6),
                              _PageStepButton(label: '-1', onTap: () => _updatePages(pagesRead - 1)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _pageController,
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                                  onSubmitted: (v) => _updatePages(int.tryParse(v) ?? pagesRead),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _PageStepButton(label: '+1', onTap: () => _updatePages(pagesRead + 1)),
                              const SizedBox(width: 6),
                              _PageStepButton(label: '+10', onTap: () => _updatePages(pagesRead + 10)),
                            ],
                          ),
                          if (pagesRead < pageCount) ...[
                            const SizedBox(height: 8),
                            Center(
                              child: TextButton(
                                onPressed: () => _updatePages(pageCount),
                                child: Text(context.tr('books.markFinished')),
                              ),
                            ),
                          ],
                        ],
                      );
                    }),
                  ],
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

class _PageStepButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PageStepButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
      child: Text(label),
    );
  }
}
