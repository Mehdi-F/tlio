import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/constants.dart';
import '../l10n/localization_context.dart';
import '../logic/reading_goal.dart';
import '../models/library_item.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../services/book_service.dart';
import '../services/link_service.dart';
import '../services/manga_service.dart';
import '../theme/app_theme.dart';
import '../utils/concurrency.dart';
import '../widgets/app_page_route.dart';
import '../widgets/skeletons.dart';
import '../widgets/surprise_me_sheet.dart';
import 'book_detail_screen.dart';
import 'friends_screen.dart';
import 'manga_detail_screen.dart';
import 'settings_screen.dart';
import 'year_recap_screen.dart';

class _Resolved {
  final LibraryItem item;
  final String title;
  final String? coverUrl;
  // Live-fetched total, used as a fallback when item.pagesTotal/volumesTotal
  // wasn't captured at add time (e.g. added before details had resolved) —
  // same rationale as books_screen's _isFinished.
  final int? liveTotal;

  _Resolved({required this.item, required this.title, required this.coverUrl, this.liveTotal});

  DateTime get recency => item.lastActivityAt ?? item.addedAt;

  _Resolved withItem(LibraryItem next) =>
      _Resolved(item: next, title: title, coverUrl: coverUrl, liveTotal: liveTotal);

  bool get isFinished {
    if (item.type == 'manga') {
      final total = item.volumesTotal ?? liveTotal;
      return total != null && (item.volumesRead ?? 0) >= total;
    }
    final total = item.pagesTotal ?? liveTotal;
    return total != null && (item.pagesRead ?? 0) >= total;
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    return _ProfileBody(
      items: library.items,
      book: context.read<BookService>(),
      manga: context.read<MangaService>(),
      user: context.watch<AuthProvider>().user,
    );
  }
}

class _ProfileBody extends StatefulWidget {
  final List<LibraryItem> items;
  final BookService book;
  final MangaService manga;
  final User? user;

  const _ProfileBody({
    required this.items,
    required this.book,
    required this.manga,
    required this.user,
  });

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  final Map<String, _Resolved> _resolved = {};
  bool _showContent = false;
  List<LibraryItem> _lastItems = const [];

  Stream<Map<int, int>>? _goals;

  @override
  void initState() {
    super.initState();
    _resolveAll(widget.items);
    final uid = widget.user?.uid;
    if (uid != null) _goals = context.read<LinkService>().watchReadingGoals(uid);
  }

  @override
  void didUpdateWidget(covariant _ProfileBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) _resolveAll(widget.items);
  }

  Timer? _flushTimer;

  @override
  void dispose() {
    _flushTimer?.cancel();
    super.dispose();
  }

  // Each resolved title used to call setState on its own, so the whole
  // profile — every filter, sort and carousel — rebuilt once per book, and
  // anything resolving after the skeleton lifted popped in one by one.
  // Results now land in _resolved silently and are flushed together.
  void _scheduleFlush() {
    if (!mounted || _flushTimer != null) return;
    _flushTimer = Timer(const Duration(milliseconds: 120), _flush);
  }

  void _flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (mounted) setState(() {});
  }

  Future<void> _resolveAll(List<LibraryItem> items) async {
    _lastItems = items;
    final keys = items.map((i) => i.docId).toSet();
    _resolved.removeWhere((k, _) => !keys.contains(k));

    // A library change is almost always progress on a title already shown
    // (a page count, a volume ticked). Its title and cover haven't changed,
    // so swap in the new item and only go to the network for new titles.
    final missing = <LibraryItem>[];
    for (final item in items) {
      final known = _resolved[item.docId];
      if (known != null) {
        _resolved[item.docId] = known.withItem(item);
      } else {
        missing.add(item);
      }
    }
    if (missing.isEmpty) {
      if (mounted) setState(() => _showContent = true);
      return;
    }

    final all = forEachBounded(missing, 8, (item) async {
      try {
        if (item.type == 'manga') {
          final details = await widget.manga.getDetails(int.parse(item.sourceId));
          _resolved[item.docId] = _Resolved(
              item: item, title: details.title, coverUrl: details.coverUrl, liveTotal: details.volumes);
        } else {
          final details = await widget.book.getDetails(item.sourceId);
          _resolved[item.docId] = _Resolved(
              item: item, title: details.title, coverUrl: details.thumbnailUrl, liveTotal: details.pageCount);
        }
        // Behind the skeleton nothing is visible yet, so there's nothing to
        // flush; once content is up, late arrivals join in batches.
        if (_showContent) _scheduleFlush();
      } catch (_) {}
    });
    await all.timeout(AppConstants.initialLoadTimeout, onTimeout: () {});
    if (!mounted) return;
    _flushTimer?.cancel();
    _flushTimer = null;
    setState(() => _showContent = true);
  }

  Future<void> _editGoal(BuildContext context, int year, int? current) async {
    final uid = widget.user?.uid;
    if (uid == null) return;
    // Captured before the dialog's await, like every write in this app.
    final links = context.read<LinkService>();
    final controller = TextEditingController(text: current?.toString() ?? '');
    // `null` = cancelled, `0` = remove, anything else = the new goal.
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('goal.title').replaceAll('{year}', '$year')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(helperText: context.tr('goal.dialogHint')),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(int.tryParse(v.trim())),
        ),
        actions: [
          if (current != null)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(0),
              child: Text(context.tr('goal.remove')),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(int.tryParse(controller.text.trim())),
            child: Text(context.tr('common.save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result < 0) return;
    await links.setReadingGoal(uid: uid, year: year, goal: result == 0 ? null : result);
  }

  Future<void> _editDisplayName(BuildContext context, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colorSurface,
        title: Text(context.tr('dialog.editProfileName')),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(context.tr('common.save')),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && context.mounted) {
      await context.read<AuthProvider>().updateDisplayName(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showContent) return const Scaffold(body: ProfileSkeleton());

    // Matches Showtime's own profile carousels (Séries/Films only include
    // started/watched titles, not the full backlog) — without this, "Livres"
    // showed every book in the library including ones never opened once.
    bool isStarted(_Resolved r) =>
        r.item.type == 'manga' ? (r.item.volumesRead ?? 0) > 0 : (r.item.pagesRead ?? 0) > 0;

    // Pair each resolved title with the *current* item: a fetch started for
    // an older snapshot can land after a newer one and would otherwise show
    // stale progress.
    final resolved = [
      for (final i in _lastItems)
        if (_resolved[i.docId] case final r?) identical(r.item, i) ? r : r.withItem(i),
    ];
    // Full per-type lists, for the top stat counts (total library size).
    final allBooks = resolved.where((r) => r.item.type == 'book').toList();
    final allComics = resolved.where((r) => r.item.type == 'comic').toList();
    final allManga = resolved.where((r) => r.item.type == 'manga').toList();

    // Carousel lists: only started/finished titles, not the full backlog.
    final books = allBooks.where(isStarted).toList()
      ..sort((a, b) => b.recency.compareTo(a.recency));
    final comics = allComics.where(isStarted).toList()
      ..sort((a, b) => b.recency.compareTo(a.recency));
    final manga = allManga.where(isStarted).toList()
      ..sort((a, b) => b.recency.compareTo(a.recency));

    int byFavoritedAt(_Resolved a, _Resolved b) =>
        (b.item.favoritedAt ?? b.recency).compareTo(a.item.favoritedAt ?? a.recency);
    final booksFav = books.where((r) => r.item.favorite).toList()..sort(byFavoritedAt);
    final comicsFav = comics.where((r) => r.item.favorite).toList()..sort(byFavoritedAt);
    final mangaFav = manga.where((r) => r.item.favorite).toList()..sort(byFavoritedAt);

    final pagesRead = resolved
        .where((r) => r.item.type != 'manga')
        .fold<int>(0, (sum, r) => sum + (r.item.pagesRead ?? 0));
    final volumesRead = resolved
        .where((r) => r.item.type == 'manga')
        .fold<int>(0, (sum, r) => sum + (r.item.volumesRead ?? 0));
    final titlesFinished = resolved.where((r) => r.isFinished).length;

    String? bannerCover;
    if (resolved.isNotEmpty) {
      final mostRecent = resolved.reduce((a, b) => a.recency.isAfter(b.recency) ? a : b);
      bannerCover = mostRecent.coverUrl;
    }

    final user = widget.user;
    final rawName = user?.displayName?.trim();
    final rawEmail = user?.email?.split('@').first.trim();
    final displayName = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : (rawEmail != null && rawEmail.isNotEmpty)
            ? rawEmail
            : context.tr('profile.title');

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _ProfileHeader(
            bannerCover: bannerCover,
            photoUrl: user?.photoURL,
            displayName: displayName,
            onEdit: () => _editDisplayName(context, displayName),
            onSignOut: () => context.read<AuthProvider>().signOut(),
            onSettings: () => Navigator.of(context).push(appRoute(builder: (_) => const SettingsScreen())),
          ),
          const SizedBox(height: 8),
          _StatsRow(
            booksCount: allBooks.length + allComics.length,
            mangaCount: allManga.length,
            titlesFinished: titlesFinished,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SurpriseMeCard(onTap: () => showSurpriseMeSheet(context)),
          ),
          if (_goals != null)
            StreamBuilder<Map<int, int>>(
              stream: _goals,
              builder: (context, snapshot) {
                // Nothing until the doc arrives, so a set goal never flashes
                // the "set a goal" prompt first.
                if (!snapshot.hasData) return const SizedBox.shrink();
                final year = DateTime.now().year;
                final goal = snapshot.data![year];
                final done = readingGoalProgress(
                  items: _lastItems,
                  isFinished: (i) => _resolved[i.docId]?.withItem(i).isFinished ?? false,
                  year: year,
                );
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _ReadingGoalCard(
                    year: year,
                    goal: goal,
                    done: done,
                    onTap: () => _editGoal(context, year, goal),
                  ),
                );
              },
            ),
          if (isRecapSeason()) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _RecapCard(
                year: currentRecapYear(),
                onTap: () => Navigator.of(context).push(appRoute(builder: (_) => YearRecapScreen(year: currentRecapYear()))),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 33, indent: 16, endIndent: 16),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).push(appRoute(builder: (_) => const FriendsScreen())),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.tr('profile.friends'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  Icon(Icons.chevron_right, color: context.colorTextSecondary),
                ],
              ),
            ),
          ),
          const Divider(height: 33, indent: 16, endIndent: 16),
          _SectionHeader(title: context.tr('profile.stats')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.menu_book,
                    label: context.tr('profile.pagesRead'),
                    value: pagesRead,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.auto_stories,
                    label: context.tr('profile.volumesRead'),
                    value: volumesRead,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _CarouselSection(title: context.tr('profile.books'), items: books),
          _CarouselSection(title: context.tr('profile.booksFavorite'), items: booksFav, showHeart: true),
          _CarouselSection(title: context.tr('profile.comics'), items: comics),
          _CarouselSection(title: context.tr('profile.comicsFavorite'), items: comicsFav, showHeart: true),
          _CarouselSection(title: context.tr('profile.manga'), items: manga),
          _CarouselSection(title: context.tr('profile.mangaFavorite'), items: mangaFav, showHeart: true),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String? bannerCover;
  final String? photoUrl;
  final String displayName;
  final VoidCallback onEdit;
  final VoidCallback onSignOut;
  final VoidCallback onSettings;

  const _ProfileHeader({
    required this.bannerCover,
    required this.photoUrl,
    required this.displayName,
    required this.onEdit,
    required this.onSignOut,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    const bannerHeight = 200.0;
    const avatarSize = 84.0;
    const spacer = 48.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            SizedBox(
              height: bannerHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (bannerCover != null)
                    CachedNetworkImage(
                      imageUrl: bannerCover!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(color: context.colorSurfaceVariant),
                    )
                  else
                    Container(color: context.colorSurfaceVariant),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: SafeArea(
                      bottom: false,
                      child: PopupMenuButton<void>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        color: context.colorSurface,
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            onTap: onSettings,
                            child: Text(context.tr('settings.title')),
                          ),
                          PopupMenuItem(
                            onTap: onSignOut,
                            child: Text(context.tr('profile.signOut')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: spacer),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colorBackground, width: 3),
                ),
                child: ClipOval(
                  child: photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: photoUrl!,
                          fit: BoxFit.cover,
                          width: avatarSize,
                          height: avatarSize,
                          errorWidget: (context, url, error) => Container(
                            color: context.colorSurfaceVariant,
                            alignment: Alignment.center,
                            child: Icon(Icons.person, color: context.colorTextSecondary, size: 40),
                          ),
                        )
                      : Container(
                          color: context.colorSurfaceVariant,
                          alignment: Alignment.center,
                          child: Icon(Icons.person, color: context.colorTextSecondary, size: 40),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton(
                      onPressed: onEdit,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(
                        context.tr('profile.editProfile'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int booksCount;
  final int mangaCount;
  final int titlesFinished;

  const _StatsRow({
    required this.booksCount,
    required this.mangaCount,
    required this.titlesFinished,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: _StatColumn(value: booksCount, label: context.tr('nav.books'))),
          const SizedBox(height: 40, child: VerticalDivider(width: 1)),
          Expanded(child: _StatColumn(value: mangaCount, label: context.tr('profile.manga'))),
          const SizedBox(height: 40, child: VerticalDivider(width: 1)),
          Expanded(child: _StatColumn(value: titlesFinished, label: context.tr('profile.titlesFinished'))),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final int value;
  final String label;

  const _StatColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: context.colorTextSecondary, fontSize: 13), textAlign: TextAlign.center),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool showHeart;

  const _SectionHeader({required this.title, this.showHeart = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          if (showHeart)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
              child: const Icon(Icons.favorite, color: Colors.white, size: 14),
            ),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;

  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: context.colorSurfaceVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: context.colorTextSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _CarouselSection extends StatelessWidget {
  final String title;
  final List<_Resolved> items;
  final bool showHeart;

  const _CarouselSection({required this.title, required this.items, this.showHeart = false});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title, showHeart: showHeart),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final r = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    appRoute(
                      builder: (_) => r.item.type == 'manga'
                          ? MangaDetailScreen(libraryItem: r.item)
                          : BookDetailScreen(libraryItem: r.item),
                    ),
                  ),
                  child: SizedBox(
                    width: 90,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: r.coverUrl != null
                          ? CachedNetworkImage(
                              imageUrl: r.coverUrl!,
                              fit: BoxFit.cover,
                              height: 130,
                              width: 90,
                              errorWidget: (context, url, error) => Container(
                                color: context.colorSurfaceVariant,
                                height: 130,
                                width: 90,
                                child: Icon(Icons.menu_book, color: context.colorTextSecondary),
                              ),
                            )
                          : Container(
                              color: context.colorSurfaceVariant,
                              height: 130,
                              width: 90,
                              child: Icon(Icons.menu_book, color: context.colorTextSecondary),
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _ReadingGoalCard extends StatelessWidget {
  final int year;
  final int? goal;
  final int done;
  final VoidCallback onTap;

  const _ReadingGoalCard({required this.year, required this.goal, required this.done, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final goal = this.goal;
    final secondary = TextStyle(color: context.colorTextSecondary, fontSize: 12);

    if (goal == null) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: context.colorSurfaceVariant, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.flag_outlined, color: AppColors.accent, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr('goal.ctaTitle').replaceAll('{year}', '$year'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    Text(context.tr('goal.ctaSubtitle'), style: secondary),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.colorTextSecondary),
            ],
          ),
        ),
      );
    }

    final reached = done >= goal;
    final String status;
    if (reached) {
      status = context.tr('goal.reached');
    } else {
      final pace = readingGoalPace(done: done, goal: goal, today: DateTime.now());
      status = pace > 0
          ? context.tr('goal.ahead').replaceAll('{n}', '$pace')
          : pace < 0
              ? context.tr('goal.behind').replaceAll('{n}', '${-pace}')
              : context.tr('goal.onPace');
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(color: context.colorSurfaceVariant, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(reached ? Icons.emoji_events_outlined : Icons.flag_outlined, color: AppColors.accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr('goal.title').replaceAll('{year}', '$year'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                Text(
                  context.tr('goal.progress').replaceAll('{done}', '$done').replaceAll('{goal}', '$goal'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (done / goal).clamp(0.0, 1.0),
                minHeight: 8,
                color: AppColors.accent,
                backgroundColor: context.colorBackground,
              ),
            ),
            const SizedBox(height: 8),
            Text(status, style: secondary),
          ],
        ),
      ),
    );
  }
}

class _SurpriseMeCard extends StatelessWidget {
  final VoidCallback onTap;

  const _SurpriseMeCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: context.colorSurfaceVariant, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.casino_outlined, color: AppColors.accent, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.tr('surprise.cardTitle'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(context.tr('surprise.cardSubtitle'), style: TextStyle(color: context.colorTextSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.colorTextSecondary),
          ],
        ),
      ),
    );
  }
}

class _RecapCard extends StatelessWidget {
  final int year;
  final VoidCallback onTap;

  const _RecapCard({required this.year, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: context.colorSurfaceVariant, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.accent, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr('recap.cardTitle').replaceAll('{year}', '$year'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  Text(context.tr('recap.cardSubtitle'), style: TextStyle(color: context.colorTextSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.colorTextSecondary),
          ],
        ),
      ),
    );
  }
}
