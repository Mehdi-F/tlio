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
      thumbnailUrl: (images?['thumbnail'] as String?)?.replaceFirst('http://', 'https://'),
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
      description: info['description'] as String? ?? '',
      pageCount: (info['pageCount'] as num?)?.toInt(),
      thumbnailUrl: (images?['thumbnail'] as String?)?.replaceFirst('http://', 'https://'),
      categories: (info['categories'] as List<dynamic>? ?? []).cast<String>(),
    );
  }
}
