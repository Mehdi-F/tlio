import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/constants.dart';
import '../l10n/localization_context.dart';
import '../models/library_item.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../services/book_service.dart';
import '../services/manga_service.dart';
import '../theme/app_theme.dart';
import '../utils/concurrency.dart';
import '../widgets/app_page_route.dart';
import '../widgets/skeletons.dart';
import 'book_detail_screen.dart';
import 'manga_detail_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _resolveAll(widget.items);
  }

  @override
  void didUpdateWidget(covariant _ProfileBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) _resolveAll(widget.items);
  }

  Future<void> _resolveAll(List<LibraryItem> items) async {
    _lastItems = items;
    final keys = items.map((i) => i.docId).toSet();
    _resolved.removeWhere((k, _) => !keys.contains(k));

    final all = forEachBounded(items, 8, (item) async {
      try {
        if (item.type == 'manga') {
          final details = await widget.manga.getDetails(int.parse(item.sourceId));
          if (mounted) {
            setState(() => _resolved[item.docId] = _Resolved(
                item: item, title: details.title, coverUrl: details.coverUrl, liveTotal: details.volumes));
          }
        } else {
          final details = await widget.book.getDetails(item.sourceId);
          if (mounted) {
            setState(() => _resolved[item.docId] = _Resolved(
                item: item, title: details.title, coverUrl: details.thumbnailUrl, liveTotal: details.pageCount));
          }
        }
      } catch (_) {}
    });
    await all.timeout(AppConstants.initialLoadTimeout, onTimeout: () {});
    if (mounted) setState(() => _showContent = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_showContent) return const Scaffold(body: ProfileSkeleton());

    final resolved = _lastItems.map((i) => _resolved[i.docId]).whereType<_Resolved>().toList();
    final books = resolved.where((r) => r.item.type == 'book').toList()
      ..sort((a, b) => b.recency.compareTo(a.recency));
    final comics = resolved.where((r) => r.item.type == 'comic').toList()
      ..sort((a, b) => b.recency.compareTo(a.recency));
    final manga = resolved.where((r) => r.item.type == 'manga').toList()
      ..sort((a, b) => b.recency.compareTo(a.recency));

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
            onSignOut: () => context.read<AuthProvider>().signOut(),
          ),
          const SizedBox(height: 8),
          _StatsRow(
            booksCount: books.length + comics.length,
            mangaCount: manga.length,
            titlesFinished: titlesFinished,
          ),
          const SizedBox(height: 12),
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
          _CarouselSection(title: context.tr('profile.comics'), items: comics),
          _CarouselSection(title: context.tr('profile.manga'), items: manga),
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
  final VoidCallback onSignOut;

  const _ProfileHeader({
    required this.bannerCover,
    required this.photoUrl,
    required this.displayName,
    required this.onSignOut,
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
                    CachedNetworkImage(imageUrl: bannerCover!, fit: BoxFit.cover)
                  else
                    Container(color: AppColors.surfaceVariant),
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
                        color: AppColors.surface,
                        itemBuilder: (context) => [
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
                  border: Border.all(color: AppColors.background, width: 3),
                ),
                child: ClipOval(
                  child: photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: photoUrl!,
                          fit: BoxFit.cover,
                          width: avatarSize,
                          height: avatarSize,
                        )
                      : Container(
                          color: AppColors.surfaceVariant,
                          alignment: Alignment.center,
                          child: const Icon(Icons.person, color: AppColors.textSecondary, size: 40),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
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
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
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
        border: Border.all(color: AppColors.surfaceVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
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

  const _CarouselSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title),
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
                            )
                          : Container(
                              color: AppColors.surfaceVariant,
                              height: 130,
                              width: 90,
                              child: const Icon(Icons.menu_book, color: AppColors.textSecondary),
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
