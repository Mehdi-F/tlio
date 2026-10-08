import '../models/library_item.dart';
import '../services/book_service.dart';
import '../services/manga_service.dart';

class YearRecap {
  final int year;
  final int titlesFinished;
  /// Books and BD finished — [titlesFinished] minus completed manga series.
  final int booksFinished;
  final int mangaVolumesRead;
  final int pagesRead;
  final int itemsAdded;

  YearRecap({
    required this.year,
    required this.titlesFinished,
    required this.booksFinished,
    required this.mangaVolumesRead,
    required this.pagesRead,
    required this.itemsAdded,
  });

  /// Progress toward the yearly reading goal, by the same rule as
  /// [readingGoalProgress]: books/BD finished plus manga volumes read.
  int get goalProgress => booksFinished + mangaVolumesRead;

  bool get isEmpty => titlesFinished == 0 && mangaVolumesRead == 0 && pagesRead == 0 && itemsAdded == 0;
}

/// Books/comics only store a single cumulative pagesRead + lastActivityAt,
/// not per-day progress — so "finished this year" and "pages read this
/// year" are approximated from whichever title's last activity fell in
/// that year, same tolerance Showtime accepts for its own recap. Manga's
/// volumeReadAt map gives an exact per-volume date, so that count is exact.
Future<YearRecap> computeYearRecap({
  required List<LibraryItem> items,
  required BookService bookService,
  required MangaService mangaService,
  required int year,
}) async {
  var titlesFinished = 0;
  var booksFinished = 0;
  var pagesRead = 0;
  var mangaVolumesRead = 0;
  final itemsAdded = items.where((i) => i.addedAt.year == year).length;

  for (final item in items) {
    if (item.type == 'manga') {
      mangaVolumesRead += item.volumeReadAt.values.where((d) => d.year == year).length;
      if ((item.lastActivityAt ?? item.addedAt).year != year) continue;
      try {
        final total = item.volumesTotal ?? (await mangaService.getDetails(int.parse(item.sourceId))).volumes;
        if (total != null && (item.volumesRead ?? 0) >= total) titlesFinished++;
      } catch (_) {}
    } else {
      if ((item.lastActivityAt ?? item.addedAt).year != year) continue;
      try {
        final total = item.pagesTotal ?? (await bookService.getDetails(item.sourceId)).pageCount;
        if (total != null && (item.pagesRead ?? 0) >= total) {
          titlesFinished++;
          booksFinished++;
          pagesRead += item.pagesRead ?? 0;
        }
      } catch (_) {}
    }
  }

  return YearRecap(
    year: year,
    titlesFinished: titlesFinished,
    booksFinished: booksFinished,
    mangaVolumesRead: mangaVolumesRead,
    pagesRead: pagesRead,
    itemsAdded: itemsAdded,
  );
}
