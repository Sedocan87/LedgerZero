enum SyncStatus {
  idle,
  syncing,
  error,
  offline,
}

class SyncState {
  final SyncStatus status;
  final String? message;
  final double? progress;

  const SyncState({this.status = SyncStatus.idle, this.message, this.progress});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          message == other.message &&
          progress == other.progress;

  @override
  int get hashCode => status.hashCode ^ message.hashCode ^ progress.hashCode;

  @override
  String toString() {
    return 'SyncState{status: $status, message: $message, progress: $progress}';
  }
}
