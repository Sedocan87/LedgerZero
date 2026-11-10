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

/// Whether Wi-Fi sync is chosen in Sync settings. Read from the stored
/// setting; a provider of an older build (Google Drive) is no sync.
final syncConfiguredProvider = Provider<bool>((ref) {
  final name = ref.watch(sharedPreferencesProvider).getString('sync_provider');
  return name == SyncProviderType.localWifi.name;
});

/// The size of the database as Android's backup copies it
/// (`db.sqlite` plus its `-wal`), in bytes; 0 when it cannot be read.
final databaseFileSizeProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(databaseGenerationProvider);
  try {
    final db = await databaseFile();
    var size = 0;
    for (final file in [db, File('${db.path}-wal')]) {
      if (await file.exists()) {
        size += await file.length();
      }
    }
    return size;
  } catch (_) {
    return 0;
  }
});

/// Android backs up at most 25 MB per app and silently stops above that;
/// above this size the Backup screen says so.
const int androidBackupSizeNote = 20 * 1024 * 1024;

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
    backupScheduler: ref.watch(backupSchedulerProvider),
    files: ref.watch(exportFileServiceProvider),
  );
});

/// Where the automatic backups live: the app's external files directory
/// (`Android/data/<app>/files`, reachable over USB and in file managers so
/// the user can copy them away), else the app documents directory. Both
/// survive the factory reset of a database that cannot be opened; neither
/// survives an uninstall or moves to a new phone.
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
    rebootstrap: ref.watch(syncRebootstrapProvider),
  );
});
