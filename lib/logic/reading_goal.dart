import '../models/library_item.dart';

/// Progress toward a yearly reading goal: every book or BD finished that
/// year, plus every manga volume read that year. One manga volume counts as
/// one book — it reads like one, and it's how reading trackers usually count
/// manga, so a goal of 24 means the same thing whatever the mix.
///
/// Dating follows [computeYearRecap] so the goal and the recap never
/// disagree: a book counts in the year of its last activity, while manga
/// volumes use their exact per-volume read dates.
///
/// [isFinished] decides whether a book or BD is complete; callers pass their
/// own because the page total may only be known from a live lookup.
int readingGoalProgress({
  required Iterable<LibraryItem> items,
  required bool Function(LibraryItem item) isFinished,
  required int year,
}) {
  var count = 0;
  for (final item in items) {
    if (item.type == 'manga') {
      count += item.volumeReadAt.values.where((d) => d.year == year).length;
    } else if ((item.lastActivityAt ?? item.addedAt).year == year && isFinished(item)) {
      count++;
    }
  }
  return count;
}

/// How far ahead (+) or behind (−) a straight-line pace toward [goal] the
/// reader is on [today], rounded to whole books.
int readingGoalPace({required int done, required int goal, required DateTime today}) {
  final start = DateTime(today.year);
  final daysInYear = DateTime(today.year + 1).difference(start).inDays;
  final elapsed = today.difference(start).inDays + 1;
  final expected = goal * elapsed / daysInYear;
  return (done - expected).round();
}
