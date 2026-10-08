import 'package:flutter_test/flutter_test.dart';
import 'package:tlio/logic/reading_goal.dart';
import 'package:tlio/models/library_item.dart';

LibraryItem _item({
  required String id,
  required String type,
  DateTime? lastActivityAt,
  Map<String, DateTime> volumeReadAt = const {},
}) {
  return LibraryItem(
    docId: id,
    sourceId: id,
    type: type,
    source: type == 'manga' ? 'anilist' : 'googlebooks',
    status: 'reading',
    addedAt: DateTime(2025, 1, 1),
    lastActivityAt: lastActivityAt,
    volumeReadAt: volumeReadAt,
  );
}

void main() {
  group('readingGoalProgress', () {
    test('counts finished books in the year and manga volumes read in the year', () {
      final items = [
        _item(id: 'b1', type: 'book', lastActivityAt: DateTime(2026, 3, 1)), // finished, 2026
        _item(id: 'b2', type: 'book', lastActivityAt: DateTime(2026, 5, 1)), // unfinished
        _item(id: 'b3', type: 'book', lastActivityAt: DateTime(2025, 12, 31)), // finished, 2025
        _item(id: 'c1', type: 'comic', lastActivityAt: DateTime(2026, 7, 1)), // BD finished, 2026
        _item(id: 'm1', type: 'manga', volumeReadAt: {
          '1': DateTime(2025, 11, 1),
          '2': DateTime(2026, 1, 10),
          '3': DateTime(2026, 2, 10),
        }),
      ];
      final done = readingGoalProgress(
        items: items,
        isFinished: (i) => i.docId != 'b2',
        year: 2026,
      );
      // b1 + c1 + two 2026 manga volumes.
      expect(done, 4);
    });

    test('a finished manga series does not count again on top of its volumes', () {
      final items = [
        _item(id: 'm1', type: 'manga', lastActivityAt: DateTime(2026, 2, 1), volumeReadAt: {
          '1': DateTime(2026, 1, 1),
          '2': DateTime(2026, 2, 1),
        }),
      ];
      expect(readingGoalProgress(items: items, isFinished: (_) => true, year: 2026), 2);
    });
  });

  group('readingGoalPace', () {
    test('on pace at the straight-line expectation', () {
      // Day 183 of 365 ≈ halfway: 12 of 24 is right on pace.
      expect(readingGoalPace(done: 12, goal: 24, today: DateTime(2026, 7, 2)), 0);
    });

    test('ahead and behind are signed whole books', () {
      expect(readingGoalPace(done: 15, goal: 24, today: DateTime(2026, 7, 2)), 3);
      expect(readingGoalPace(done: 9, goal: 24, today: DateTime(2026, 7, 2)), -3);
    });

    test('January 1st expects almost nothing yet', () {
      expect(readingGoalPace(done: 0, goal: 24, today: DateTime(2026, 1, 1)), 0);
    });
  });
}
