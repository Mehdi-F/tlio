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

  group('parseIsbn', () {
    test('accepts ISBN-13 with or without hyphens and spaces', () {
      expect(parseIsbn('9781804994252'), '9781804994252');
      expect(parseIsbn('978-1-8049-9425-2'), '9781804994252');
      expect(parseIsbn(' 978 1 8049 9425 2 '), '9781804994252');
    });

    test('accepts ISBN-10, including an X check digit', () {
      expect(parseIsbn('0-316-76948-7'), '0316769487');
      expect(parseIsbn('080442957x'), '080442957X');
    });

    test('rejects a wrong check digit', () {
      expect(parseIsbn('9781804994253'), isNull);
      expect(parseIsbn('0316769488'), isNull);
    });

    test('leaves titles and other numbers alone', () {
      expect(parseIsbn('Tales of the City'), isNull);
      expect(parseIsbn('1984'), isNull);
      expect(parseIsbn('1234567890123'), isNull);
    });
  });

  group('BnF records', () {
    // Trimmed from the real SRU response for 978-2-36846-939-2.
    const xml = '''
<srw:record><srw:recordData><oai_dc:dc>
<dc:title>Pénis de table : sept mecs racontent tout sur leur vie sexuelle. [1] / texte et dessin, Cookie Kalkair</dc:title>
<dc:creator>Kalkair, Cookie (1983-....). Auteur du texte</dc:creator>
<dc:creator>Kalkair, Cookie (1983-....). Illustrateur</dc:creator>
</oai_dc:dc></srw:recordData></srw:record>''';

    test('reduces a librarian-style record to title and author', () {
      final record = parseBnfRecord(xml);
      expect(record?.title, 'Pénis de table');
      expect(record?.author, 'Cookie Kalkair');
    });

    test('the cleaned title exact-matches the Google listing', () {
      final results = [
        _r('t2', 'Pénis de table Tome 2'),
        _r('t1', 'Pénis de table'),
      ];
      final record = parseBnfRecord(xml)!;
      expect(pickIsbnMatch(results, isbn: '9782368469392', title: record.title)?.id, 't1');
    });

    test('a response without records gives null', () {
      expect(parseBnfRecord('<srw:numberOfRecords>0</srw:numberOfRecords>'), isNull);
    });

    test('decodes entities and keeps uninverted names', () {
      final record = parseBnfRecord('<dc:title>Tintin &amp; Milou</dc:title><dc:creator>Hergé (1907-1983)</dc:creator>');
      expect(record?.title, 'Tintin & Milou');
      expect(record?.author, 'Hergé');
    });
  });
}
