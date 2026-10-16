import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/data/database/connection.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/services/error/local_error_reporting_service.dart';

/// Deletes everything LedgerZero stores on this device and returns the app
/// to the "not onboarded" state. Used by Settings > Factory reset and by the
/// login screen when the key vault is missing (the data can no longer be
/// unlocked, and Settings is unreachable while locked).
class FactoryResetService {
  FactoryResetService(this._ref);

  final Ref _ref;

  /// Locks the session (closes the database, zeroes the key), deletes the
  /// database with its WAL/SHM files, every key vault / legacy / biometric
  /// key entry, exported files, local error reports and preferences, and
  /// marks the app as not onboarded. The caller navigates to onboarding.
  Future<void> reset() async {
    await _ref.read(sessionProvider.notifier).lock();
    await deleteDatabaseFiles();
    await _ref.read(keyVaultProvider).delete();
    await _ref.read(legacyKeyMaterialProvider).deleteAll();
    await _ref.read(biometricKeyStoreProvider).delete();
    await _ref.read(exportFileServiceProvider).deleteAll();
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
