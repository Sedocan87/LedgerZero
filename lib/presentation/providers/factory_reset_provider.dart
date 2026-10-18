import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/connection.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/presentation/providers/notification_capture_providers.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/services/error/local_error_reporting_service.dart';
import 'package:ledger_zero/services/sync/sync_outbox.dart';

/// Deletes everything LedgerZero stores on this device and returns the app
/// to the "not onboarded" state. Used by Settings > Factory reset and by the
/// lock screen when the database key is missing (the data can no longer be
/// opened, and Settings is unreachable).
///
/// Every step runs even when an earlier one fails; the first error is
/// rethrown at the end so the caller can report it.
class FactoryResetService {
  FactoryResetService({
    required this.closeSession,
    required this.deleteDatabase,
    required this.deleteDeviceKey,
    required this.deleteLegacyKeys,
    required this.deleteExports,
    required this.clearCapturedNotifications,
    required this.deleteErrorReports,
    required this.unpairWifiSync,
    required this.deleteSyncFiles,
    required this.clearPreferences,
    required this.markNotOnboarded,
  });

  /// Closes the session (closes the database, zeroes the key).
  final Future<void> Function() closeSession;

  /// Deletes the database with its WAL/SHM files and every restore leftover.
  final Future<void> Function() deleteDatabase;
  final Future<void> Function() deleteDeviceKey;

  /// Key vault / legacy / biometric key entries of older versions.
  final Future<void> Function() deleteLegacyKeys;
  final Future<void> Function() deleteExports;

  /// Captured card notifications with their settings.
  final Future<void> Function() clearCapturedNotifications;
  final Future<void> Function() deleteErrorReports;

  /// Forgets the Wi-Fi pairing secret and the paired phones, so a
  /// re-onboarded phone cannot serve the old folder to the old peer.
  final Future<void> Function() unpairWifiSync;

  /// `<documents>/sync` (outbox and Wi-Fi sync folder).
  final Future<void> Function() deleteSyncFiles;

  /// Preferences (the app lock setting and the sync device id included).
  final Future<void> Function() clearPreferences;
  final void Function() markNotOnboarded;

  Future<void> reset() async {
    Object? firstError;
    StackTrace? firstStack;
    for (final (name, step) in <(String, Future<void> Function())>[
      ('close session', closeSession),
      ('delete database', deleteDatabase),
      ('delete device key', deleteDeviceKey),
      ('delete legacy keys', deleteLegacyKeys),
      ('delete exports', deleteExports),
      ('clear captured notifications', clearCapturedNotifications),
      ('delete error reports', deleteErrorReports),
      ('unpair Wi-Fi sync', unpairWifiSync),
      ('delete sync files', deleteSyncFiles),
      ('clear preferences', clearPreferences),
    ]) {
      try {
        await step();
      } catch (e, stack) {
        Logger.error('Factory reset: $name failed', e, stack);
        firstError ??= e;
        firstStack ??= stack;
      }
    }
    markNotOnboarded();
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStack!);
    }
  }
}

final factoryResetServiceProvider = Provider<FactoryResetService>((ref) {
  return FactoryResetService(
    closeSession: () => ref.read(sessionProvider.notifier).close(),
    deleteDatabase: deleteDatabaseFiles,
    deleteDeviceKey: () => ref.read(deviceKeyStoreProvider).delete(),
    deleteLegacyKeys: () =>
        ref.read(legacyKeyMigrationProvider).deleteLeftovers(),
    deleteExports: () => ref.read(exportFileServiceProvider).deleteAll(),
    clearCapturedNotifications: () =>
        ref.read(notificationCaptureChannelProvider).clear(),
    deleteErrorReports: () => LocalErrorReportingService().deleteAll(),
    unpairWifiSync: () => ref.read(lanSyncServiceProvider).unpair(),
    deleteSyncFiles: SyncOutbox.deleteAllSyncFiles,
    clearPreferences: () => ref.read(sharedPreferencesProvider).clear(),
    markNotOnboarded: () {
      ref.read(authProvider.notifier)
        ..setAuthenticated(false)
        ..setOnboarded(false);
    },
  );
});
