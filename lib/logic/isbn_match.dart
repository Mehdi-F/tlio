import '../models/book_models.dart';

/// Picks the search result that best matches a scanned book.
///
/// The fallback search for a scan is a plain "title author" query, and
/// Google ranks by its own relevance — scanning *Tales of the City* put the
/// omnibus *28 Barbary Lane* ("Tales of the City" Books 1-3) first, ahead of
/// the novel itself. So, in order:
///  1. a result listing the scanned ISBN — the exact edition;
///  2. a result whose title is exactly [title], ignoring case, accents and
///     punctuation (Open Library writes "a l'ecole", Google "à l'école");
///  3. otherwise Google's top result.
/// Returns null only when [results] is empty.
BookSearchResult? pickIsbnMatch(
  List<BookSearchResult> results, {
  required String isbn,
  String? title,
}) {
  if (results.isEmpty) return null;

  final scanned = _digits(isbn);
  for (final r in results) {
    if (r.isbns.any((i) => _digits(i) == scanned)) return r;
  }

  if (title != null) {
    final wanted = normalizeTitle(title);
    if (wanted.isNotEmpty) {
      for (final r in results) {
        if (normalizeTitle(r.title) == wanted) return r;
      }
    }
  }

  return results.first;
}

String _digits(String s) => s.replaceAll(RegExp(r'[^0-9Xx]'), '').toUpperCase();

const _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'ÿ': 'y', 'ñ': 'n', 'œ': 'oe', 'æ': 'ae',
};

/// Lowercase, accents folded, anything that isn't a letter or digit dropped —
/// so "Harry Potter à l'école des sorciers" and "Harry Potter a l'ecole des
/// Sorciers" compare equal.
String normalizeTitle(String s) {
  final lower = s.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_accents[ch] ?? ch);
  }
  return buffer.toString().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
