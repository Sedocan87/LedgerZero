class ServerException implements Exception {
  final String message;
  ServerException(this.message);
}

class CacheException implements Exception {
  final String message;
  CacheException(this.message);
}

class DatabaseException implements Exception {
  final String message;
  final Object? originalError;
  DatabaseException(this.message, [this.originalError]);

  @override
  String toString() => 'DatabaseException: $message ${originalError != null ? "($originalError)" : ""}';
}
