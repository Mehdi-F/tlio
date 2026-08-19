import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/anilist_config.dart';
import '../config/constants.dart';
import '../exceptions/app_exception.dart';
import '../models/manga_models.dart';

class MangaService {
  final http.Client _client;
  SharedPreferences? _prefs;

  MangaService({http.Client? client}) : _client = client ?? http.Client() {
    unawaited(SharedPreferences.getInstance().then((p) => _prefs = p));
  }

  static const _prefsKeyPrefix = 'anilist_cache:';
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

  Future<String> _cachedQuery(String cacheKey, String query, Map<String, dynamic> variables, String errorLabel) {
    final existing = _memoryCache[cacheKey];
    if (existing != null) return existing;
    final future = _fetchQuery(cacheKey, query, variables, errorLabel).catchError((Object e, StackTrace st) {
      _memoryCache.remove(cacheKey);
      throw e;
    });
    _memoryCache[cacheKey] = future;
    return future;
  }

  Future<String> _fetchQuery(
    String cacheKey,
    String query,
    Map<String, dynamic> variables,
    String errorLabel,
  ) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;

    final prefsKey = '$_prefsKeyPrefix$cacheKey';
    final cachedAt = prefs.getInt('$prefsKey:at');
    final cachedBody = prefs.getString(prefsKey);
    if (cachedAt != null && cachedBody != null) {
      final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(cachedAt));
      if (age < _prefsTtl) return cachedBody;
    }

    try {
      final response = await _client
          .post(
            Uri.parse(AniListConfig.endpoint),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({'query': query, 'variables': variables}),
          )
          .timeout(_requestTimeout);
      if (response.statusCode != 200) {
        throw AniListException('$errorLabel failed', statusCode: response.statusCode);
      }
      unawaited(prefs.setString(prefsKey, response.body));
      unawaited(prefs.setInt('$prefsKey:at', DateTime.now().millisecondsSinceEpoch));
      return response.body;
    } catch (e) {
      if (cachedBody != null) return cachedBody;
      if (e is AniListException) rethrow;
      throw AniListException('$errorLabel failed: $e');
    }
  }

  static const _searchQuery = r'''
    query ($search: String) {
      Page(page: 1, perPage: 20) {
        media(search: $search, type: MANGA) {
          id
          title { romaji english }
          coverImage { large }
          volumes
        }
      }
    }
  ''';

  static const _detailsQuery = r'''
    query ($id: Int) {
      Media(id: $id, type: MANGA) {
        id
        title { romaji english }
        coverImage { large }
        description(asHtml: false)
        volumes
        chapters
        genres
      }
    }
  ''';

  /// Search is not cached, same rationale as `BookService.search`.
  Future<List<MangaSearchResult>> search(String query) async {
    final response = await _client
        .post(
          Uri.parse(AniListConfig.endpoint),
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({'query': _searchQuery, 'variables': {'search': query}}),
        )
        .timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw AniListException('Search failed', statusCode: response.statusCode);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final media = body['data']?['Page']?['media'] as List<dynamic>? ?? [];
    return media.map((m) => MangaSearchResult.fromJson(m as Map<String, dynamic>)).toList();
  }

  Future<MangaDetails> getDetails(int id) async {
    final body = await _cachedQuery('details:$id', _detailsQuery, {'id': id}, 'Get manga details');
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    return MangaDetails.fromJson(decoded['data']?['Media'] as Map<String, dynamic>);
  }

  static const _discoverQuery = r'''
    query ($sort: [MediaSort]) {
      Page(page: 1, perPage: 15) {
        media(type: MANGA, sort: $sort) {
          id
          title { romaji english }
          coverImage { large }
          volumes
        }
      }
    }
  ''';

  Future<List<MangaSearchResult>> discover({required String sort}) async {
    final body = await _cachedQuery('discover:$sort', _discoverQuery, {'sort': [sort]}, 'Discover manga');
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final media = decoded['data']?['Page']?['media'] as List<dynamic>? ?? [];
    return media.map((m) => MangaSearchResult.fromJson(m as Map<String, dynamic>)).toList();
  }
}
