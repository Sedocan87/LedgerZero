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
  String toString() =>
      'DatabaseException: $message ${originalError != null ? "($originalError)" : ""}';
}

/// What went wrong in a sync, for a localised message in the UI.
enum SyncErrorKind {
  /// No connection or a timeout.
  network,

  /// Not signed in to the cloud provider.
  notSignedIn,

  /// The provider rejected the sign-in; the user has to reconnect.
  authFailed,

  /// The cloud storage is full.
  storageFull,

  /// iCloud is off or not signed in on this device.
  iCloudUnavailable,

  /// Anything else (the details are logged).
  other,
}

class SyncException implements Exception {
  /// Technical detail for logs and diagnostics (English, never shown as
  /// such: the UI shows a localised text for [kind]).
  final String message;
  final Object? originalError;
  final bool retryable;
  final SyncErrorKind kind;

  const SyncException(
    this.message, {
    this.originalError,
    this.retryable = false,
    this.kind = SyncErrorKind.other,
  });

  // Alias for backward compatibility if needed, but better to use `retryable` consistently
  bool get isRetryable => retryable;

  @override
  String toString() =>
      'SyncException: $message ${originalError != null ? "($originalError)" : ""}';
}
