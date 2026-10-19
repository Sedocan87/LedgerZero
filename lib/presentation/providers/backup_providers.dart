import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/data/database/connection.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/services/backup/auto_backup_service.dart';
import 'package:ledger_zero/services/backup/backup_scheduler.dart';
import 'package:ledger_zero/services/backup/backup_service.dart';
import 'package:ledger_zero/services/backup/restore_service.dart';
import 'package:ledger_zero/services/backup/sync_rebootstrap.dart';
import 'package:ledger_zero/services/export/export_file_service.dart';
import 'package:path_provider/path_provider.dart';

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

/// Whether this phone has personal accounts of its own member. Their
/// transactions never sync, so only this phone's backups hold them.
final ownPersonalAccountsProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final accounts = await ref.watch(accountRepositoryProvider).getAllAccounts();
  return accounts.any((a) => a.owner == AccountOwner.me);
});

/// The last backup is older than this (or missing) while personal accounts
/// exist: the Backup screen shows a "Back up now" nudge.
const Duration backupNudgeAfter = Duration(days: 7);

final backupNudgeProvider = FutureProvider.autoDispose<bool>((ref) async {
  if (!await ref.watch(ownPersonalAccountsProvider.future)) {
    return false;
  }
  final last = ref.watch(backupSchedulerProvider).lastBackup;
  return last == null || DateTime.now().difference(last) > backupNudgeAfter;
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

/// Where the automatic backups live: the app's external files directory
/// (`Android/data/<app>/files`, reachable over USB and in file managers so
/// the user can copy them away), else the app documents directory. Both
/// survive a lost database key; neither survives an uninstall.
Future<Directory> autoBackupBaseDirectory() async {
  try {
    final external = await getExternalStorageDirectory();
    if (external != null) {
      return external;
    }
  } catch (_) {
    // Not available on this platform or storage not mounted.
  }
  return getApplicationDocumentsDirectory();
}

final autoBackupServiceProvider = Provider<AutoBackupService>((ref) {
  return AutoBackupService(
    ref.watch(sharedPreferencesProvider),
    ref.watch(secureStoreProvider),
    backupService: () => ref.read(backupServiceProvider),
    baseDirectory: autoBackupBaseDirectory,
  );
});

/// Bumped after an automatic backup setting or run changed, so the Backup
/// screen re-reads the status and the file list.
final autoBackupGenerationProvider = StateProvider<int>((ref) => 0);

/// The automatic backups on this phone, newest first.
final autoBackupFilesProvider =
    FutureProvider.autoDispose<List<AutoBackupFile>>((ref) {
      ref.watch(autoBackupGenerationProvider);
      return ref.watch(autoBackupServiceProvider).listBackups();
    });

/// The folder of the automatic backups (shown on the Backup screen).
final autoBackupFolderProvider = FutureProvider<Directory>(
  (ref) => ref.watch(autoBackupServiceProvider).directory(),
);

final syncRebootstrapProvider = Provider<SyncRebootstrap>((ref) {
  return SyncRebootstrap(
    ref.watch(sharedPreferencesProvider),
    ref.watch(syncOutboxProvider),
  );
});

class _ProviderDatabaseLifecycle implements DatabaseLifecycle {
  final Ref _ref;
  _ProviderDatabaseLifecycle(this._ref);

  /// Sync is paused first: a run must neither write the database nor
  /// generate change files while the file is swapped and the re-bootstrap
  /// flag is set.
  @override
  Future<void> close() async {
    await _ref.read(syncControllerProvider.notifier).pause();
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
    final db = _ref.read(databaseProvider);
    _ref.read(syncControllerProvider.notifier).resume();
    return db;
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
