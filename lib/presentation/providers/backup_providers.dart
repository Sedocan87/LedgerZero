import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/services/backup/backup_scheduler.dart';
import 'package:ledger_zero/services/backup/backup_service.dart';
import 'package:ledger_zero/services/backup/restore_service.dart';

final backupSchedulerProvider = Provider<BackupScheduler>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  return BackupScheduler(prefs, notificationService);
});

final backupServiceProvider = Provider<BackupService>((ref) {
  final googleDrive = ref.watch(googleDriveServiceProvider);
  final iCloudDrive = ref.watch(iCloudDriveServiceProvider);
  final scheduler = ref.watch(backupSchedulerProvider);

  return BackupService(
    ref.read(databaseProvider),
    googleDriveService: googleDrive,
    iCloudDriveService: iCloudDrive,
    backupScheduler: scheduler,
  );
});

final restoreServiceProvider = Provider<RestoreService>((ref) {
  return RestoreService(ref.read(databaseProvider));
});
