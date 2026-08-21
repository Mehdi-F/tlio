import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/html_utils.dart';

String? _isbnFrom(Map<String, dynamic> info) {
  final identifiers = (info['industryIdentifiers'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  for (final type in ['ISBN_13', 'ISBN_10']) {
    for (final identifier in identifiers) {
      if (identifier['type'] == type) return identifier['identifier'] as String?;
    }
  }
  return null;
}

/// Google Books' cover CDN never sends CORS headers, so on Flutter web the
/// image request succeeds at the network level but the browser blocks the
/// response from being read — covers silently fail to render. Open
/// Library's cover CDN does support CORS, so web prefers it (by ISBN) and
/// falls back to Google's thumbnail — which still works fine natively on
/// Android, where CORS doesn't apply.
String? _coverUrl(Map<String, dynamic>? images, String? isbn) {
  final googleUrl = (images?['thumbnail'] as String?)?.replaceFirst('http://', 'https://');
  if (kIsWeb && isbn != null) return 'https://covers.openlibrary.org/b/isbn/$isbn-L.jpg';
  return googleUrl;
}

class BookSearchResult {
  final String id;
  final String title;
  final List<String> authors;
  final String? thumbnailUrl;

  BookSearchResult({required this.id, required this.title, required this.authors, required this.thumbnailUrl});

  factory BookSearchResult.fromJson(Map<String, dynamic> json) {
    final info = json['volumeInfo'] as Map<String, dynamic>? ?? {};
    final images = info['imageLinks'] as Map<String, dynamic>?;
    return BookSearchResult(
      id: json['id'] as String,
      title: info['title'] as String? ?? 'Sans titre',
      authors: (info['authors'] as List<dynamic>? ?? []).cast<String>(),
      thumbnailUrl: _coverUrl(images, _isbnFrom(info)),
    );
  }
}

class BookDetails {
  final String id;
  final String title;
  final List<String> authors;
  final String description;
  final int? pageCount;
  final String? thumbnailUrl;
  final List<String> categories;

  BookDetails({
    required this.id,
    required this.title,
    required this.authors,
    required this.description,
    required this.pageCount,
    required this.thumbnailUrl,
    required this.categories,
  });

  factory BookDetails.fromJson(Map<String, dynamic> json) {
    final info = json['volumeInfo'] as Map<String, dynamic>? ?? {};
    final images = info['imageLinks'] as Map<String, dynamic>?;
    return BookDetails(
      id: json['id'] as String,
      title: info['title'] as String? ?? 'Sans titre',
      authors: (info['authors'] as List<dynamic>? ?? []).cast<String>(),
      description: stripHtml(info['description'] as String? ?? ''),
      pageCount: (info['pageCount'] as num?)?.toInt(),
      thumbnailUrl: _coverUrl(images, _isbnFrom(info)),
      categories: (info['categories'] as List<dynamic>? ?? []).cast<String>(),
    );
  }
}
