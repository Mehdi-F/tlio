import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/anilist_config.dart';
import '../config/constants.dart';
import '../exceptions/app_exception.dart';
import '../models/manga_models.dart';
import 'response_cache.dart';

class MangaService {
  final http.Client _client;
  final _diskCache = ResponseCache(
    name: 'anilist_cache',
    ttl: AppConstants.cacheTtl,
    legacyPrefsPrefix: 'anilist_cache:',
  );

  MangaService({http.Client? client}) : _client = client ?? http.Client();

  static const _requestTimeout = AppConstants.requestTimeout;

  final Map<String, Future<String>> _memoryCache = {};

  void clearCache() {
    _memoryCache.clear();
    unawaited(_diskCache.clear());
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
    final fresh = await _diskCache.readFresh(cacheKey);
    if (fresh != null) return fresh;

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
      unawaited(_diskCache.write(cacheKey, response.body));
      return response.body;
    } catch (e) {
      // A stale copy still opens the title, which beats an outright failure.
      final stale = await _diskCache.readStale(cacheKey);
      if (stale != null) return stale;
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
