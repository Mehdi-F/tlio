abstract class AppException implements Exception {
  final String message;

  AppException(this.message);

  @override
  String toString() => message;
}

class GoogleBooksException extends AppException {
  final int? statusCode;

  GoogleBooksException(super.message, {this.statusCode});

  @override
  String toString() =>
      statusCode != null ? 'GoogleBooksException ($statusCode): $message' : 'GoogleBooksException: $message';
}

class AniListException extends AppException {
  final int? statusCode;

  AniListException(super.message, {this.statusCode});

  @override
  String toString() =>
      statusCode != null ? 'AniListException ($statusCode): $message' : 'AniListException: $message';
}

class NetworkException extends AppException {
  NetworkException(super.message);

  @override
  String toString() => 'NetworkException: $message';
}

class AuthException extends AppException {
  AuthException(super.message);

  @override
  String toString() => 'AuthException: $message';
}

class DataException extends AppException {
  final String? details;

  DataException(super.message, {this.details});

  @override
  String toString() => details != null ? 'DataException: $message ($details)' : 'DataException: $message';
}

class NotFoundException extends AppException {
  NotFoundException(super.message);

  @override
  String toString() => 'NotFoundException: $message';
}
