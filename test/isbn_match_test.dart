import 'package:flutter_test/flutter_test.dart';
import 'package:tlio/logic/isbn_match.dart';
import 'package:tlio/models/book_models.dart';

BookSearchResult _r(String id, String title, [List<String> isbns = const []]) =>
    BookSearchResult(id: id, title: title, authors: const [], thumbnailUrl: null, isbns: isbns);

void main() {
  // Google's real order for "Tales of the City Armistead Maupin": the
  // omnibus first, the novel third.
  final talesResults = [
    _r('omnibus', '28 Barbary Lane', ['9780062683007', '0062683004']),
    _r('omnibus2', 'Back to Barbary Lane', ['9780062683021']),
    _r('novel', 'Tales Of The City', ['9781448126927', '1448126924']),
    _r('sequel', 'More Tales Of The City', ['9781448126941']),
  ];

  test('an exact title match beats the omnibus Google ranks first', () {
    final best = pickIsbnMatch(talesResults, isbn: '9781804994252', title: 'Tales of the City');
    expect(best?.id, 'novel');
  });

  test('a result listing the scanned ISBN wins over everything', () {
    final results = [
      ...talesResults,
      _r('exact-edition', 'Tales of the City (Penguin)', ['978-1-8049-9425-2']),
    ];
    final best = pickIsbnMatch(results, isbn: '9781804994252', title: 'Tales of the City');
    expect(best?.id, 'exact-edition');
  });

  test('titles compare without case, accents or punctuation', () {
    final results = [
      _r('other', 'Harry Potter et la Chambre des secrets'),
      _r('hp1', "Harry Potter à l'école des sorciers"),
    ];
    final best = pickIsbnMatch(results, isbn: '9782070584628', title: "Harry Potter a l'ecole des sorciers");
    expect(best?.id, 'hp1');
  });

  test('a prefix of a longer title is not an exact match', () {
    final best = pickIsbnMatch(talesResults.reversed.toList(), isbn: '0', title: 'Tales of the City');
    // "More Tales Of The City" now comes first but must not be picked.
    expect(best?.id, 'novel');
  });

  test('falls back to the top result when nothing matches', () {
    final best = pickIsbnMatch(talesResults, isbn: '0', title: 'Something else entirely');
    expect(best?.id, 'omnibus');
  });

  test('empty results give null', () {
    expect(pickIsbnMatch(const [], isbn: '0', title: 'x'), isNull);
  });
}
