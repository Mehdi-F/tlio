import '../utils/date_utils.dart';

class LibraryItem {
  final String docId;
  final String sourceId; // Google Books volume ID or AniList media ID
  final String type; // "book" | "comic" | "manga"
  final String source; // "googlebooks" | "anilist"
  final String status; // "reading" | "completed" | "plan_to_read"
  final DateTime addedAt;
  final bool favorite;
  final DateTime? favoritedAt;
  final DateTime? lastActivityAt;
  final int? pagesRead; // book only
  final int? pagesTotal; // book only
  final int? volumesRead; // comic/manga only
  final int? volumesTotal; // comic/manga only
  final Map<String, DateTime> volumeReadAt; // manga only, key = volume number as string
  final int rereadCount;

  LibraryItem({
    required this.docId,
    required this.sourceId,
    required this.type,
    required this.source,
    required this.status,
    required this.addedAt,
    this.favorite = false,
    this.favoritedAt,
    this.lastActivityAt,
    this.pagesRead,
    this.pagesTotal,
    this.volumesRead,
    this.volumesTotal,
    this.volumeReadAt = const {},
    this.rereadCount = 0,
  });

  LibraryItem copyWith({
    String? status,
    bool? favorite,
    DateTime? favoritedAt,
    DateTime? lastActivityAt,
    int? pagesRead,
    int? volumesRead,
    Map<String, DateTime>? volumeReadAt,
  }) =>
      LibraryItem(
        docId: docId,
        sourceId: sourceId,
        type: type,
        source: source,
        status: status ?? this.status,
        addedAt: addedAt,
        favorite: favorite ?? this.favorite,
        favoritedAt: favoritedAt ?? this.favoritedAt,
        lastActivityAt: lastActivityAt ?? this.lastActivityAt,
        pagesRead: pagesRead ?? this.pagesRead,
        pagesTotal: pagesTotal,
        volumesRead: volumesRead ?? this.volumesRead,
        volumesTotal: volumesTotal,
        volumeReadAt: volumeReadAt ?? this.volumeReadAt,
        rereadCount: rereadCount,
      );

  static String buildDocId({required String sourceId, required String type}) => '${type}_$sourceId';

  factory LibraryItem.fromMap(String docId, Map<String, dynamic> map) {
    try {
      return LibraryItem(
        docId: docId,
        sourceId: map['sourceId'] as String? ?? '',
        type: map['type'] as String? ?? 'book',
        source: map['source'] as String? ?? 'googlebooks',
        status: map['status'] as String? ?? 'reading',
        addedAt: tryParseDateTime(map['addedAt']) ?? DateTime.now(),
        favorite: map['favorite'] as bool? ?? false,
        favoritedAt: tryParseDateTime(map['favoritedAt']),
        lastActivityAt: tryParseDateTime(map['lastActivityAt']),
        pagesRead: (map['pagesRead'] as num?)?.toInt(),
        pagesTotal: (map['pagesTotal'] as num?)?.toInt(),
        volumesRead: (map['volumesRead'] as num?)?.toInt(),
        volumesTotal: (map['volumesTotal'] as num?)?.toInt(),
        volumeReadAt: (map['volumeReadAt'] as Map? ?? {}).map((k, v) {
          final parsed = tryParseDateTime(v);
          return MapEntry(k as String, parsed ?? DateTime.now());
        }),
        rereadCount: (map['rereadCount'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      throw FormatException('Invalid library item format for docId=$docId: $e');
    }
  }

  Map<String, dynamic> toMap() => {
        'sourceId': sourceId,
        'type': type,
        'source': source,
        'status': status,
        'addedAt': addedAt.toIso8601String(),
        'favorite': favorite,
        'favoritedAt': favoritedAt?.toIso8601String(),
        'lastActivityAt': lastActivityAt?.toIso8601String(),
        'pagesRead': pagesRead,
        'pagesTotal': pagesTotal,
        'volumesRead': volumesRead,
        'volumesTotal': volumesTotal,
        'volumeReadAt': volumeReadAt.map((k, v) => MapEntry(k, v.toIso8601String())),
        'rereadCount': rereadCount,
      };
}
