import 'package:equatable/equatable.dart';

enum SyncStatus {
  disconnected,
  connected,
  syncing,
  error,
}

class SyncState extends Equatable {
  final SyncStatus status;
  final DateTime? lastSyncTime;
  final String? errorMessage;
  final String? accountEmail;

  const SyncState({
    this.status = SyncStatus.disconnected,
    this.lastSyncTime,
    this.errorMessage,
    this.accountEmail,
  });

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncTime,
    String? errorMessage,
    String? accountEmail,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      errorMessage: errorMessage ?? this.errorMessage,
      accountEmail: accountEmail ?? this.accountEmail,
    );
  }

  @override
  List<Object?> get props => [status, lastSyncTime, errorMessage, accountEmail];
}
