import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// On-disk cache for raw API response bodies, one file per request.
///
/// These bodies used to be stored as SharedPreferences entries, which turned
/// out to be a startup-crash waiting to happen: SharedPreferences loads its
/// entire store into memory (and marshals it across the platform channel) on
/// every launch, so an unbounded pile of cached JSON eventually gets too big
/// to load at all. Showtime hit exactly that — a fatal ~106MB allocation
/// before any app code could run — so TLIO uses files here instead. They're
/// read only on demand and the OS can reclaim the cache directory under
/// storage pressure.
class ResponseCache {
  final String name;
  final Duration ttl;
  final String legacyPrefsPrefix;

  Future<Directory>? _dirFuture;

  ResponseCache({
    required this.name,
    required this.ttl,
    required this.legacyPrefsPrefix,
  }) {
    unawaited(_dir());
    unawaited(_purgeLegacyPrefs());
  }

  Future<Directory> _dir() {
    return _dirFuture ??= () async {
      final base = await getApplicationCacheDirectory();
      final dir = Directory('${base.path}/$name');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }();
  }

  Future<File> _fileFor(String key) async {
    final dir = await _dir();
    // Keys carry ids and query text; hash them into a flat filename.
    return File('${dir.path}/${md5.convert(utf8.encode(key))}');
  }

  /// Drops entries written by the previous SharedPreferences-backed cache so
  /// existing installs shed that weight instead of carrying it forever.
  Future<void> _purgeLegacyPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stale =
          prefs.getKeys().where((k) => k.startsWith(legacyPrefsPrefix)).toList();
      for (final key in stale) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  /// Returns the cached body if it exists and is younger than [ttl].
  Future<String?> readFresh(String key) async {
    try {
      final file = await _fileFor(key);
      if (!await file.exists()) return null;
      if (DateTime.now().difference(await file.lastModified()) >= ttl) {
        return null;
      }
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  /// Returns the cached body whatever its age — used as a fallback when the
  /// network call fails, since stale data beats an error.
  Future<String?> readStale(String key) async {
    try {
      final file = await _fileFor(key);
      return await file.exists() ? await file.readAsString() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, String body) async {
    try {
      await (await _fileFor(key)).writeAsString(body);
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      final dir = await _dir();
      if (await dir.exists()) await dir.delete(recursive: true);
      _dirFuture = null;
    } catch (_) {}
  }
}
