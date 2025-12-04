import 'package:equatable/equatable.dart';

enum SyncStatus {
  disconnected,
  connected,
  syncing,
  error,
}

enum SyncProviderType {
  none,
  googleDrive,
  iCloud,
}

class SyncState extends Equatable {
  final SyncStatus status;
  final SyncProviderType selectedProvider;
  final DateTime? lastSyncTime;
  final String? errorMessage;
  final String? accountEmail;

  const SyncState({
    this.status = SyncStatus.disconnected,
    this.selectedProvider = SyncProviderType.none,
    this.lastSyncTime,
    this.errorMessage,
    this.accountEmail,
  });

  SyncState copyWith({
    SyncStatus? status,
    SyncProviderType? selectedProvider,
    DateTime? lastSyncTime,
    String? errorMessage,
    String? accountEmail,
  }) {
    return SyncState(
      status: status ?? this.status,
      selectedProvider: selectedProvider ?? this.selectedProvider,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      errorMessage: errorMessage ?? this.errorMessage,
      accountEmail: accountEmail ?? this.accountEmail,
    );
  }

  @override
  List<Object?> get props => [
        status,
        selectedProvider,
        lastSyncTime,
        errorMessage,
        accountEmail,
      ];
}
