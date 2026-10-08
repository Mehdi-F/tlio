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

/// Returns [input] as a bare ISBN (digits, plus a trailing X for ISBN-10)
/// when it is one, else null — so a search box can tell "9781804994252" or
/// "978-1-8049-9425-2" from a title.
///
/// The check digit is verified: an arbitrary 10- or 13-digit number typed
/// as a search term stays an ordinary search instead of being misread as
/// an ISBN.
String? parseIsbn(String input) {
  final s = input.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
  if (RegExp(r'^97[89]\d{10}$').hasMatch(s)) {
    var sum = 0;
    for (var i = 0; i < 13; i++) {
      sum += int.parse(s[i]) * (i.isEven ? 1 : 3);
    }
    return sum % 10 == 0 ? s : null;
  }
  if (RegExp(r'^\d{9}[\dX]$').hasMatch(s)) {
    var sum = 0;
    for (var i = 0; i < 10; i++) {
      sum += (s[i] == 'X' ? 10 : int.parse(s[i])) * (10 - i);
    }
    return sum % 11 == 0 ? s : null;
  }
  return null;
}

/// A title and author found for an ISBN by a catalogue other than Google
/// Books, used to search Google Books for the matching volume.
typedef IsbnRecord = ({String title, String author});

/// Extracts title and author from a BnF SRU response in Dublin Core.
///
/// BnF records are written for librarians: the title carries the subtitle,
/// volume number and statement of responsibility ("Pénis de table : sept
/// mecs racontent tout sur leur vie sexuelle. [1] / texte et dessin, Cookie
/// Kalkair") and the creator is inverted with dates and role ("Kalkair,
/// Cookie (1983-....). Auteur du texte"). Both are reduced to what a Google
/// Books search and an exact-title comparison need. Returns null when the
/// response holds no record.
IsbnRecord? parseBnfRecord(String xml) {
  final rawTitle = RegExp(r'<dc:title>([\s\S]*?)</dc:title>').firstMatch(xml)?.group(1);
  if (rawTitle == null) return null;
  final title = cleanBnfTitle(_decodeXmlEntities(rawTitle));
  if (title.isEmpty) return null;
  final rawCreator = RegExp(r'<dc:creator>([\s\S]*?)</dc:creator>').firstMatch(xml)?.group(1);
  final author = rawCreator == null ? '' : cleanBnfCreator(_decodeXmlEntities(rawCreator));
  return (title: title, author: author);
}

/// "Pénis de table : sept mecs… [1] / texte et dessin, Cookie Kalkair"
/// → "Pénis de table".
String cleanBnfTitle(String raw) {
  var t = raw;
  final slash = t.indexOf(' / ');
  if (slash >= 0) t = t.substring(0, slash);
  final colon = t.indexOf(' : ');
  if (colon >= 0) t = t.substring(0, colon);
  t = t.replaceAll(RegExp(r'\[[^\]]*\]'), '');
  return t.replaceAll(RegExp(r'[\s.,;:]+$'), '').trim();
}

/// "Kalkair, Cookie (1983-....). Auteur du texte" → "Cookie Kalkair".
String cleanBnfCreator(String raw) {
  var c = raw;
  final paren = c.indexOf('(');
  if (paren >= 0) c = c.substring(0, paren);
  c = c.split('. ').first.trim().replaceAll(RegExp(r'[.,;]+$'), '');
  final parts = c.split(', ');
  return parts.length == 2 ? '${parts[1].trim()} ${parts[0].trim()}' : c.trim();
}

String _decodeXmlEntities(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');
