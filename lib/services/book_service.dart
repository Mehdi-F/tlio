import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/google_books_config.dart';
import '../config/constants.dart';
import '../exceptions/app_exception.dart';
import '../models/book_models.dart';
import 'response_cache.dart';

class BookService {
  final http.Client _client;
  final _diskCache = ResponseCache(
    name: 'googlebooks_cache',
    ttl: AppConstants.cacheTtl,
    legacyPrefsPrefix: 'googlebooks_cache:',
  );

  BookService({http.Client? client}) : _client = client ?? http.Client();

  static const _requestTimeout = AppConstants.requestTimeout;

  final Map<String, Future<String>> _memoryCache = {};

  void clearCache() {
    _memoryCache.clear();
    unawaited(_diskCache.clear());
  }

  Future<String> _cachedBody(String key, Uri uri, String errorLabel) {
    final existing = _memoryCache[key];
    if (existing != null) return existing;
    final future = _fetchBody(key, uri, errorLabel).catchError((Object e, StackTrace st) {
      _memoryCache.remove(key);
      throw e;
    });
    _memoryCache[key] = future;
    return future;
  }

  Future<String> _fetchBody(String key, Uri uri, String errorLabel) async {
    final fresh = await _diskCache.readFresh(key);
    if (fresh != null) return fresh;

    try {
      final response = await _getWithRetry(uri);
      if (response.statusCode != 200) {
        throw GoogleBooksException('$errorLabel failed', statusCode: response.statusCode);
      }
      unawaited(_diskCache.write(key, response.body));
      return response.body;
    } catch (e) {
      // A stale copy still opens the title, which beats an outright failure.
      final stale = await _diskCache.readStale(key);
      if (stale != null) return stale;
      if (e is GoogleBooksException) rethrow;
      throw GoogleBooksException('$errorLabel failed: $e');
    }
  }

  Uri _withKey(Uri uri) {
    if (GoogleBooksConfig.apiKey.isEmpty) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, 'key': GoogleBooksConfig.apiKey});
  }

  /// Google Books intermittently returns 503 on an otherwise-valid request
  /// — reproducible with plain curl outside the browser, and confirmed via
  /// Cloud Console to not be a quota issue (queries/day sat under 10% used
  /// during a run of failures). It's backend flakiness on Google's side,
  /// sometimes in bursts of several failures in a row, so this retries
  /// several times with a growing delay rather than giving up after one
  /// or two — cheap insurance against a service that's known to be
  /// under-maintained.
  Future<http.Response> _getWithRetry(Uri uri, {int retries = 4}) async {
    for (var attempt = 0; ; attempt++) {
      final response = await _client.get(uri).timeout(_requestTimeout);
      if (response.statusCode < 500 || attempt >= retries) return response;
      await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
    }
  }

  /// Search is deliberately not cached — it has its own always-fresh
  /// expectation, same rationale as Showtime's `TmdbService.search`.
  Future<List<BookSearchResult>> search(String query) async {
    final uri = _withKey(Uri.parse('${GoogleBooksConfig.baseUrl}/volumes').replace(
      queryParameters: {'q': query, 'maxResults': '20'},
    ));
    final response = await _getWithRetry(uri);
    if (response.statusCode != 200) {
      throw GoogleBooksException('Search failed', statusCode: response.statusCode);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = body['items'] as List<dynamic>? ?? [];
    return items.map((i) => BookSearchResult.fromJson(i as Map<String, dynamic>)).toList();
  }

  /// Resolves a scanned ISBN to Google Books volumes, best match first.
  ///
  /// Google's own `isbn:` operator is the direct route, but at the time of
  /// writing it returns zero results even for famous editions (The Catcher
  /// in the Rye, Bloomsbury's Harry Potter), with or without a key. Open
  /// Library knows far more ISBNs — French editions and BD included — so
  /// when the direct lookup comes back empty, its title and author drive an
  /// ordinary Google Books search instead. Returns an empty list when
  /// neither source knows the ISBN.
  Future<List<BookSearchResult>> searchByIsbn(String isbn) async {
    try {
      final direct = await search('isbn:$isbn');
      if (direct.isNotEmpty) return direct;
    } on Exception {
      // A 503 after retries or a timeout — fall through, Open Library may
      // still know it.
    }

    final uri = Uri.https('openlibrary.org', '/api/books', {
      'bibkeys': 'ISBN:$isbn',
      'format': 'json',
      'jscmd': 'data',
    });
    final response = await _client.get(uri).timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw GoogleBooksException('ISBN lookup failed', statusCode: response.statusCode);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final record = body['ISBN:$isbn'] as Map<String, dynamic>?;
    final title = (record?['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return const [];
    final authors = record?['authors'] as List<dynamic>? ?? const [];
    final author = authors.isEmpty ? '' : ((authors.first as Map<String, dynamic>)['name'] as String? ?? '');
    return search('$title $author'.trim());
  }

  Future<BookDetails> getDetails(String id) async {
    final uri = _withKey(Uri.parse('${GoogleBooksConfig.baseUrl}/volumes/$id'));
    final body = await _cachedBody('details:$id', uri, 'Get book details');
    return BookDetails.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  /// Google Books has no trending/bestseller endpoint, so "discover" is a
  /// subject-search browse row instead — cached like details, unlike search.
  Future<List<BookSearchResult>> discover(String subject) async {
    final uri = _withKey(Uri.parse('${GoogleBooksConfig.baseUrl}/volumes').replace(
      queryParameters: {'q': 'subject:$subject', 'orderBy': 'relevance', 'maxResults': '15'},
    ));
    final body = await _cachedBody('discover:$subject', uri, 'Discover books');
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final items = decoded['items'] as List<dynamic>? ?? [];
    return items.map((i) => BookSearchResult.fromJson(i as Map<String, dynamic>)).toList();
  }
}
