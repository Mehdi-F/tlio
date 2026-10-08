import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/localization_context.dart';
import '../logic/friend_comparison.dart';
import '../providers/library_provider.dart';
import '../services/book_service.dart';
import '../services/library_service.dart';
import '../services/manga_service.dart';
import '../theme/app_theme.dart';
import '../widgets/skeletons.dart';

class FriendComparisonScreen extends StatefulWidget {
  final String friendUid;
  final String friendName;

  const FriendComparisonScreen({super.key, required this.friendUid, required this.friendName});

  @override
  State<FriendComparisonScreen> createState() => _FriendComparisonScreenState();
}

class _FriendComparisonScreenState extends State<FriendComparisonScreen> {
  ComparisonResult? _result;
  bool _loading = true;
  bool _error = false;

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
    // Same as FriendProfileScreen._load: read everything off context before
    // the first await, so leaving mid-load can't throw on a disposed element.
    final myItems = context.read<LibraryProvider>().items;
    final library = context.read<LibraryService>();
    final book = context.read<BookService>();
    final manga = context.read<MangaService>();
    try {
      final friendItems = await library.watchLibrary(widget.friendUid).first;
      final result = await computeFriendComparison(
        myItems: myItems,
        friendItems: friendItems,
        book: book,
        manga: manga,
      );
      if (mounted) setState(() => _result = result);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('compare.title'))),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
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
    final result = _result!;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _TotalsCard(result: result, friendName: widget.friendName),
        const SizedBox(height: 24),
        Text(
          context.tr('compare.commonTitles'),
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: context.colorTextSecondary),
        ),
        const SizedBox(height: 8),
        if (result.commonTitles.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(context.tr('compare.noCommon'), style: TextStyle(color: context.colorTextSecondary)),
          )
        else
          ...result.commonTitles.map((t) => _CommonTitleRow(title: t, friendName: widget.friendName)),
      ],
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final ComparisonResult result;
  final String friendName;

  const _TotalsCard({required this.result, required this.friendName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.colorSurfaceVariant, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _CompareRow(
            label: context.tr('profile.pagesRead'),
            myValue: result.myPagesRead,
            friendValue: result.friendPagesRead,
            friendName: friendName,
          ),
          const SizedBox(height: 16),
          _CompareRow(
            label: context.tr('profile.volumesRead'),
            myValue: result.myVolumesRead,
            friendValue: result.friendVolumesRead,
            friendName: friendName,
          ),
          const SizedBox(height: 16),
          _CompareRow(
            label: context.tr('profile.titlesFinished'),
            myValue: result.myTitlesFinished,
            friendValue: result.friendTitlesFinished,
            friendName: friendName,
          ),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  final String label;
  final int myValue;
  final int friendValue;
  final String friendName;

  const _CompareRow({required this.label, required this.myValue, required this.friendValue, required this.friendName});

  @override
  Widget build(BuildContext context) {
    final iAmAhead = myValue > friendValue;
    final friendAhead = friendValue > myValue;
    return Column(
      children: [
        Text(label, style: TextStyle(color: context.colorTextSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CompareValue(label: context.tr('compare.you'), value: myValue, highlighted: iAmAhead),
            Text('vs', style: TextStyle(color: context.colorTextSecondary)),
            _CompareValue(label: friendName, value: friendValue, highlighted: friendAhead),
          ],
        ),
      ],
    );
  }
}

class _CompareValue extends StatelessWidget {
  final String label;
  final int value;
  final bool highlighted;

  const _CompareValue({required this.label, required this.value, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: highlighted ? AppColors.accent : context.colorTextPrimary,
          ),
        ),
        Text(label, style: TextStyle(color: context.colorTextSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _CommonTitleRow extends StatelessWidget {
  final CommonTitle title;
  final String friendName;

  const _CommonTitleRow({required this.title, required this.friendName});

  @override
  Widget build(BuildContext context) {
    final myRatio = title.total == 0 ? 0.0 : (title.myCount / title.total).clamp(0.0, 1.0);
    final friendRatio = title.total == 0 ? 0.0 : (title.friendCount / title.total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 48,
              height: 68,
              child: title.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: title.coverUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: context.colorSurfaceVariant,
                        child: Icon(
                          title.type == 'manga' ? Icons.auto_stories : Icons.menu_book,
                          color: context.colorTextSecondary,
                          size: 18,
                        ),
                      ),
                    )
                  : Container(
                      color: context.colorSurfaceVariant,
                      child: Icon(
                        title.type == 'manga' ? Icons.auto_stories : Icons.menu_book,
                        color: context.colorTextSecondary,
                        size: 18,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.title, style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                _ProgressLine(label: context.tr('compare.you'), ratio: myRatio, count: title.myCount, total: title.total),
                const SizedBox(height: 4),
                _ProgressLine(label: friendName, ratio: friendRatio, count: title.friendCount, total: title.total),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final String label;
  final double ratio;
  final int count;
  final int total;

  const _ProgressLine({required this.label, required this.ratio, required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label, style: TextStyle(color: context.colorTextSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: ratio, minHeight: 6, backgroundColor: context.colorSurface, color: AppColors.accent),
          ),
        ),
        const SizedBox(width: 8),
        Text('$count/$total', style: TextStyle(color: context.colorTextSecondary, fontSize: 11)),
      ],
    );
  }
}
