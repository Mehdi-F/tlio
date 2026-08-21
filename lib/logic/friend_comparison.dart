import '../models/library_item.dart';
import '../services/book_service.dart';
import '../services/manga_service.dart';
import '../utils/concurrency.dart';

class CommonTitle {
  final String type; // 'book' | 'comic' | 'manga'
  final String sourceId;
  final String title;
  final String? coverUrl;
  final int myCount;
  final int friendCount;
  final int total;

  CommonTitle({
    required this.type,
    required this.sourceId,
    required this.title,
    required this.coverUrl,
    required this.myCount,
    required this.friendCount,
    required this.total,
  });
}

class ComparisonResult {
  final int myPagesRead;
  final int friendPagesRead;
  final int myVolumesRead;
  final int friendVolumesRead;
  final int myTitlesFinished;
  final int friendTitlesFinished;
  final List<CommonTitle> commonTitles;

  ComparisonResult({
    required this.myPagesRead,
    required this.friendPagesRead,
    required this.myVolumesRead,
    required this.friendVolumesRead,
    required this.myTitlesFinished,
    required this.friendTitlesFinished,
    required this.commonTitles,
  });
}

/// Compares two libraries: aggregate totals plus per-title progress for
/// whatever the two users both have (same type + sourceId).
Future<ComparisonResult> computeFriendComparison({
  required List<LibraryItem> myItems,
  required List<LibraryItem> friendItems,
  required BookService book,
  required MangaService manga,
}) async {
  String key(LibraryItem i) => '${i.type}:${i.sourceId}';
  final myByKey = {for (final i in myItems) key(i): i};
  final friendByKey = {for (final i in friendItems) key(i): i};
  final commonKeys = myByKey.keys.toSet().intersection(friendByKey.keys.toSet()).toList();

  final myPagesRead = myItems.where((i) => i.type != 'manga').fold<int>(0, (s, i) => s + (i.pagesRead ?? 0));
  final friendPagesRead = friendItems.where((i) => i.type != 'manga').fold<int>(0, (s, i) => s + (i.pagesRead ?? 0));
  final myVolumesRead = myItems.where((i) => i.type == 'manga').fold<int>(0, (s, i) => s + (i.volumesRead ?? 0));
  final friendVolumesRead = friendItems.where((i) => i.type == 'manga').fold<int>(0, (s, i) => s + (i.volumesRead ?? 0));

  bool isFinished(LibraryItem item, int? liveTotal) {
    final total = item.type == 'manga' ? item.volumesTotal ?? liveTotal : item.pagesTotal ?? liveTotal;
    final read = item.type == 'manga' ? item.volumesRead : item.pagesRead;
    return total != null && (read ?? 0) >= total;
  }

  final common = List<CommonTitle?>.filled(commonKeys.length, null);
  await forEachBounded(List.generate(commonKeys.length, (i) => i), 6, (i) async {
    final k = commonKeys[i];
    final mine = myByKey[k]!;
    final theirs = friendByKey[k]!;
    try {
      if (mine.type == 'manga') {
        final details = await manga.getDetails(int.parse(mine.sourceId));
        final total = mine.volumesTotal ?? details.volumes ?? 0;
        common[i] = CommonTitle(
          type: 'manga',
          sourceId: mine.sourceId,
          title: details.title,
          coverUrl: details.coverUrl,
          myCount: mine.volumesRead ?? 0,
          friendCount: theirs.volumesRead ?? 0,
          total: total,
        );
      } else {
        final details = await book.getDetails(mine.sourceId);
        final total = mine.pagesTotal ?? details.pageCount ?? 0;
        common[i] = CommonTitle(
          type: mine.type,
          sourceId: mine.sourceId,
          title: details.title,
          coverUrl: details.thumbnailUrl,
          myCount: mine.pagesRead ?? 0,
          friendCount: theirs.pagesRead ?? 0,
          total: total,
        );
      }
    } catch (_) {}
  });

  final commonTitles = common.whereType<CommonTitle>().toList()..sort((a, b) => a.title.compareTo(b.title));

  // Titles-finished needs each item's live total resolved too, so it's
  // computed separately rather than folded above.
  var myFinished = 0;
  await forEachBounded(myItems, 8, (item) async {
    try {
      final liveTotal = item.type == 'manga'
          ? (await manga.getDetails(int.parse(item.sourceId))).volumes
          : (await book.getDetails(item.sourceId)).pageCount;
      if (isFinished(item, liveTotal)) myFinished++;
    } catch (_) {}
  });
  var friendFinished = 0;
  await forEachBounded(friendItems, 8, (item) async {
    try {
      final liveTotal = item.type == 'manga'
          ? (await manga.getDetails(int.parse(item.sourceId))).volumes
          : (await book.getDetails(item.sourceId)).pageCount;
      if (isFinished(item, liveTotal)) friendFinished++;
    } catch (_) {}
  });

  return ComparisonResult(
    myPagesRead: myPagesRead,
    friendPagesRead: friendPagesRead,
    myVolumesRead: myVolumesRead,
    friendVolumesRead: friendVolumesRead,
    myTitlesFinished: myFinished,
    friendTitlesFinished: friendFinished,
    commonTitles: commonTitles,
  );
}
