import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/data/database/connection.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/services/backup/backup_scheduler.dart';
import 'package:ledger_zero/services/backup/backup_service.dart';
import 'package:ledger_zero/services/backup/restore_service.dart';
import 'package:ledger_zero/services/backup/sync_rebootstrap.dart';
import 'package:ledger_zero/services/export/export_file_service.dart';

final exportFileServiceProvider = Provider<ExportFileService>(
  (ref) => ExportFileService(),
);

final backupSchedulerProvider = Provider<BackupScheduler>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  return BackupScheduler(prefs, notificationService);
});

/// The cloud storage chosen in Sync settings, or null when none is set up.
final backupCloudTargetProvider = Provider<BackupCloudTarget?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final name = prefs.getString('sync_provider');
  if (name == SyncProviderType.googleDrive.name) {
    return BackupCloudTarget.googleDrive;
  }
  return null;
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    // watch: a re-login or restore opens a new connection.
    ref.watch(databaseProvider),
    googleDriveService: ref.watch(googleDriveServiceProvider),
    backupScheduler: ref.watch(backupSchedulerProvider),
    files: ref.watch(exportFileServiceProvider),
  );
});

final syncRebootstrapProvider = Provider<SyncRebootstrap>((ref) {
  return SyncRebootstrap(
    ref.watch(sharedPreferencesProvider),
    ref.watch(syncOutboxProvider),
  );
});

class _ProviderDatabaseLifecycle implements DatabaseLifecycle {
  final Ref _ref;
  _ProviderDatabaseLifecycle(this._ref);

  @override
  Future<void> close() async {
    if (_ref.exists(databaseProvider)) {
      try {
        await closeDatabaseOnce(_ref.read(databaseProvider));
      } on DatabaseLockedException {
        // Nothing open.
      }
    }
  }

  @override
  Future<AppDatabase> reopen() async {
    _ref.read(databaseGenerationProvider.notifier).state++;
    return _ref.read(databaseProvider);
  }
}

final restoreServiceProvider = Provider<RestoreService>((ref) {
  return RestoreService(
    () => ref.read(databaseProvider),
    lifecycle: _ProviderDatabaseLifecycle(ref),
    databaseFile: databaseFile,
    dataKey: () {
      final key = ref.read(sessionProvider).key;
      if (key == null || key.isDestroyed) {
        throw const DatabaseLockedException();
      }
      return key.bytes;
    },
    rebootstrap: ref.watch(syncRebootstrapProvider),
  );
});
