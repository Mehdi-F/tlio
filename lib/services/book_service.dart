import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/google_books_config.dart';
import '../config/constants.dart';
import '../exceptions/app_exception.dart';
import '../models/book_models.dart';

class BookService {
  final http.Client _client;
  SharedPreferences? _prefs;

  BookService({http.Client? client}) : _client = client ?? http.Client() {
    unawaited(SharedPreferences.getInstance().then((p) => _prefs = p));
  }

  static const _prefsKeyPrefix = 'googlebooks_cache:';
  static const _prefsTtl = AppConstants.cacheTtl;
  static const _requestTimeout = AppConstants.requestTimeout;

  final Map<String, Future<String>> _memoryCache = {};

  void clearCache() {
    _memoryCache.clear();
    final prefs = _prefs;
    if (prefs == null) return;
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_prefsKeyPrefix)) unawaited(prefs.remove(key));
    }
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
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;

    final prefsKey = '$_prefsKeyPrefix$key';
    final cachedAt = prefs.getInt('$prefsKey:at');
    final cachedBody = prefs.getString(prefsKey);
    if (cachedAt != null && cachedBody != null) {
      final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(cachedAt));
      if (age < _prefsTtl) return cachedBody;
    }

    try {
      final response = await _getWithRetry(uri);
      if (response.statusCode != 200) {
        throw GoogleBooksException('$errorLabel failed', statusCode: response.statusCode);
      }
      unawaited(prefs.setString(prefsKey, response.body));
      unawaited(prefs.setInt('$prefsKey:at', DateTime.now().millisecondsSinceEpoch));
      return response.body;
    } catch (e) {
      if (cachedBody != null) return cachedBody;
      if (e is GoogleBooksException) rethrow;
      throw GoogleBooksException('$errorLabel failed: $e');
    }
  }

  Uri _withKey(Uri uri) {
    if (GoogleBooksConfig.apiKey.isEmpty) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, 'key': GoogleBooksConfig.apiKey});
  }

  /// Google Books intermittently returns 503 on an otherwise-valid request
  /// (reproducible with plain curl, no browser/CORS involved) — a couple of
  /// short retries clears most of them instead of surfacing a hard error
  /// for what's really just backend flakiness.
  Future<http.Response> _getWithRetry(Uri uri, {int retries = 2}) async {
    for (var attempt = 0; ; attempt++) {
      final response = await _client.get(uri).timeout(_requestTimeout);
      if (response.statusCode < 500 || attempt >= retries) return response;
      await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
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
