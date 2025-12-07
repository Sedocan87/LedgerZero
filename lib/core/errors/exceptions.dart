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
  const DatabaseException(this.message, [this.originalError]);

  @override
  String toString() => 'DatabaseException: $message ${originalError != null ? "($originalError)" : ""}';
}

class SyncException implements Exception {
  final String message;
  final Object? originalError;
  final bool retryable;

  const SyncException(this.message, {this.originalError, this.retryable = false});

  // Alias for backward compatibility if needed, but better to use `retryable` consistently
  bool get isRetryable => retryable;

  @override
  String toString() => 'SyncException: $message ${originalError != null ? "($originalError)" : ""}';
}
