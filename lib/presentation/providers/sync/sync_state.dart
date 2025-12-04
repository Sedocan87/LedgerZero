import 'package:equatable/equatable.dart';

enum SyncStatus {
  idle,
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
  final String? message;
  final double? progress;
  final bool wifiOnly;

  const SyncState({
    this.status = SyncStatus.disconnected,
    this.selectedProvider = SyncProviderType.none,
    this.lastSyncTime,
    this.errorMessage,
    this.accountEmail,
    this.message,
    this.progress,
    this.wifiOnly = false,
  });

  SyncState copyWith({
    SyncStatus? status,
    SyncProviderType? selectedProvider,
    DateTime? lastSyncTime,
    String? errorMessage,
    String? accountEmail,
    String? message,
    double? progress,
    bool? wifiOnly,
  }) {
    return SyncState(
      status: status ?? this.status,
      selectedProvider: selectedProvider ?? this.selectedProvider,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      errorMessage: errorMessage ?? this.errorMessage,
      accountEmail: accountEmail ?? this.accountEmail,
      message: message ?? this.message,
      progress: progress ?? this.progress,
      wifiOnly: wifiOnly ?? this.wifiOnly,
    );
  }

  @override
  List<Object?> get props => [
        status,
        selectedProvider,
        lastSyncTime,
        errorMessage,
        accountEmail,
        message,
        progress,
        wifiOnly,
      ];
}
