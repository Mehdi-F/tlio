class MangaSearchResult {
  final int id;
  final String title;
  final String? coverUrl;
  final int? volumes;

  MangaSearchResult({required this.id, required this.title, required this.coverUrl, required this.volumes});

  factory MangaSearchResult.fromJson(Map<String, dynamic> json) {
    final title = json['title'] as Map<String, dynamic>? ?? {};
    final cover = json['coverImage'] as Map<String, dynamic>?;
    return MangaSearchResult(
      id: json['id'] as int,
      title: (title['english'] as String?) ?? (title['romaji'] as String?) ?? 'Sans titre',
      coverUrl: cover?['large'] as String?,
      volumes: json['volumes'] as int?,
    );
  }
}

class MangaDetails {
  final int id;
  final String title;
  final String? coverUrl;
  final String description;
  final int? volumes;
  final int? chapters;
  final List<String> genres;

  MangaDetails({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.description,
    required this.volumes,
    required this.chapters,
    required this.genres,
  });

  factory MangaDetails.fromJson(Map<String, dynamic> json) {
    final title = json['title'] as Map<String, dynamic>? ?? {};
    final cover = json['coverImage'] as Map<String, dynamic>?;
    return MangaDetails(
      id: json['id'] as int,
      title: (title['english'] as String?) ?? (title['romaji'] as String?) ?? 'Sans titre',
      coverUrl: cover?['large'] as String?,
      description: (json['description'] as String?) ?? '',
      volumes: json['volumes'] as int?,
      chapters: json['chapters'] as int?,
      genres: (json['genres'] as List<dynamic>? ?? []).cast<String>(),
    );
  }
}
