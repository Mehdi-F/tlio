class GoogleBooksConfig {
  static const baseUrl = 'https://www.googleapis.com/books/v1';
  // Optional — Google Books works unauthenticated at low volume; set via
  // --dart-define=GOOGLE_BOOKS_API_KEY=... only if quota errors show up.
  static const apiKey = String.fromEnvironment('GOOGLE_BOOKS_API_KEY');
}
