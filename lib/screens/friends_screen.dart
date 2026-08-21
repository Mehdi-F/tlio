import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/constants.dart';
import '../l10n/localization_context.dart';
import '../models/library_item.dart';
import '../providers/auth_provider.dart';
import '../services/book_service.dart';
import '../services/library_service.dart';
import '../services/link_service.dart';
import '../services/manga_service.dart';
import '../theme/app_theme.dart';
import '../utils/concurrency.dart';
import '../widgets/app_page_route.dart';
import '../widgets/skeletons.dart';
import 'book_detail_screen.dart';
import 'friend_comparison_screen.dart';
import 'manga_detail_screen.dart';

/// TLIO is locked to exactly two people, so there's no friend list or
/// add-by-email flow to build — this screen goes straight to whoever the
/// other allowed user is (via LinkService.findOtherUser).
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  bool _loading = true;
  Map<String, dynamic>? _friend;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final myEmail = context.read<AuthProvider>().user?.email ?? '';
    final friend = await context.read<LinkService>().findOtherUser(myEmail);
    if (mounted) {
      setState(() {
        _friend = friend;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('friends.title'))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const MediaListSkeleton()
            : _friend == null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.people_outline, size: 48, color: context.colorTextSecondary),
                            const SizedBox(height: 16),
                            Text(
                              context.tr('friends.placeholder'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: context.colorTextSecondary, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : _FriendProfile(
                    friendUid: _friend!['uid'] as String,
                    displayName: _friend!['displayName'] as String? ?? _friend!['email'] as String? ?? '',
                    photoUrl: _friend!['photoUrl'] as String?,
                  ),
      ),
    );
  }
}

class _Resolved {
  final LibraryItem item;
  final String title;
  final String? coverUrl;
  final DateTime recency;

  _Resolved({required this.item, required this.title, required this.coverUrl, required this.recency});
}

class _FriendProfile extends StatefulWidget {
  final String friendUid;
  final String displayName;
  final String? photoUrl;

  const _FriendProfile({required this.friendUid, required this.displayName, required this.photoUrl});

  @override
  State<_FriendProfile> createState() => _FriendProfileState();
}

class _FriendProfileState extends State<_FriendProfile> {
  bool _loading = true;
  bool _error = false;
  List<_Resolved> _resolved = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final items = await context.read<LibraryService>().watchLibrary(widget.friendUid).first;
      final book = context.read<BookService>();
      final manga = context.read<MangaService>();
      final resolved = List<_Resolved?>.filled(items.length, null);
      await forEachBounded(List.generate(items.length, (i) => i), 8, (i) async {
        final item = items[i];
        try {
          if (item.type == 'manga') {
            final details = await manga.getDetails(int.parse(item.sourceId));
            resolved[i] = _Resolved(
              item: item,
              title: details.title,
              coverUrl: details.coverUrl,
              recency: item.lastActivityAt ?? item.addedAt,
            );
          } else {
            final details = await book.getDetails(item.sourceId);
            resolved[i] = _Resolved(
              item: item,
              title: details.title,
              coverUrl: details.thumbnailUrl,
              recency: item.lastActivityAt ?? item.addedAt,
            );
          }
        } catch (_) {}
      }).timeout(AppConstants.initialLoadTimeout, onTimeout: () {});
      if (mounted) setState(() => _resolved = resolved.whereType<_Resolved>().toList());
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const MediaListSkeleton();
    if (_error) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              context.tr('compare.error'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colorTextSecondary),
            ),
          ),
        ],
      );
    }

    final books = _resolved.where((r) => r.item.type != 'manga' && (r.item.pagesRead ?? 0) > 0).toList()
      ..sort((a, b) => b.recency.compareTo(a.recency));
    final manga = _resolved.where((r) => r.item.type == 'manga' && (r.item.volumesRead ?? 0) > 0).toList()
      ..sort((a, b) => b.recency.compareTo(a.recency));
    final pagesRead = _resolved.where((r) => r.item.type != 'manga').fold<int>(0, (s, r) => s + (r.item.pagesRead ?? 0));
    final volumesRead = _resolved.where((r) => r.item.type == 'manga').fold<int>(0, (s, r) => s + (r.item.volumesRead ?? 0));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: context.colorSurfaceVariant,
                backgroundImage: widget.photoUrl != null ? CachedNetworkImageProvider(widget.photoUrl!) : null,
                child: widget.photoUrl == null ? Icon(Icons.person, color: context.colorTextSecondary, size: 36) : null,
              ),
              const SizedBox(height: 12),
              Text(widget.displayName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text('$pagesRead', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  Text(context.tr('profile.pagesRead'), style: TextStyle(color: context.colorTextSecondary, fontSize: 12)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text('$volumesRead', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  Text(context.tr('profile.volumesRead'), style: TextStyle(color: context.colorTextSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(appRoute(
                builder: (_) => FriendComparisonScreen(friendUid: widget.friendUid, friendName: widget.displayName),
              )),
              icon: const Icon(Icons.bar_chart, size: 18),
              label: Text(context.tr('compare.cardTitle')),
            ),
          ),
        ),
        const Divider(height: 33, indent: 16, endIndent: 16),
        if (books.isNotEmpty) ..._carousel(context, context.tr('profile.books'), books),
        if (manga.isNotEmpty) ..._carousel(context, context.tr('profile.manga'), manga),
        if (books.isEmpty && manga.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(context.tr('friends.emptyLibrary'), style: TextStyle(color: context.colorTextSecondary)),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  List<Widget> _carousel(BuildContext context, String title, List<_Resolved> items) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
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
                onTap: () => Navigator.of(context).push(appRoute(
                  builder: (_) => r.item.type == 'manga'
                      ? MangaDetailScreen.preview(id: int.parse(r.item.sourceId))
                      : BookDetailScreen.preview(id: r.item.sourceId),
                )),
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
                              child: Icon(
                                r.item.type == 'manga' ? Icons.auto_stories : Icons.menu_book,
                                color: context.colorTextSecondary,
                              ),
                            ),
                          )
                        : Container(
                            color: context.colorSurfaceVariant,
                            height: 130,
                            width: 90,
                            child: Icon(
                              r.item.type == 'manga' ? Icons.auto_stories : Icons.menu_book,
                              color: context.colorTextSecondary,
                            ),
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 12),
    ];
  }
}
