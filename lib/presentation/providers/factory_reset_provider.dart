import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/data/database/connection.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/presentation/providers/notification_capture_providers.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/services/error/local_error_reporting_service.dart';

/// Deletes everything LedgerZero stores on this device and returns the app
/// to the "not onboarded" state. Used by Settings > Factory reset and by the
/// lock screen when the database key is missing (the data can no longer be
/// opened, and Settings is unreachable).
class FactoryResetService {
  FactoryResetService(this._ref);

  final Ref _ref;

  /// Closes the session (closes the database, zeroes the key), deletes the
  /// database with its WAL/SHM files, the device key and any key vault /
  /// legacy / biometric key entry of older versions, exported files, local
  /// error reports, captured card notifications with their settings and
  /// preferences (the app lock setting included), and marks the app as not
  /// onboarded. The caller navigates to onboarding.
  Future<void> reset() async {
    await _ref.read(sessionProvider.notifier).close();
    await deleteDatabaseFiles();
    await _ref.read(deviceKeyStoreProvider).delete();
    await _ref.read(legacyKeyMigrationProvider).deleteLeftovers();
    await _ref.read(exportFileServiceProvider).deleteAll();
    await _ref.read(notificationCaptureChannelProvider).clear();
    await LocalErrorReportingService().deleteAll();
    await _ref.read(sharedPreferencesProvider).clear();
    _ref.read(authProvider.notifier)
      ..setAuthenticated(false)
      ..setOnboarded(false);
  }
}

final factoryResetServiceProvider = Provider<FactoryResetService>(
  FactoryResetService.new,
);
