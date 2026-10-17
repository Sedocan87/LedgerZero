import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/data/database/connection.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/services/security/biometric_key_store.dart';
import 'package:ledger_zero/services/security/device_key_store.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:ledger_zero/services/security/key_vault.dart';
import 'package:ledger_zero/services/security/legacy_key_material.dart';
import 'package:ledger_zero/services/security/legacy_key_migration.dart';
import 'package:ledger_zero/services/security/secure_store.dart';
import 'package:ledger_zero/services/security/unlock_service.dart';

/// Reading the database while no session is open (before start-up opened
/// it, during a factory reset or restore).
class DatabaseLockedException implements Exception {
  const DatabaseLockedException();
  @override
  String toString() => 'DatabaseLockedException: the database is not open';
}

/// The data key of the open session. Owned by [SessionController]; zeroed
/// when the session closes.
class DatabaseKey {
  final Uint8List _bytes;
  bool _destroyed = false;

  DatabaseKey(Uint8List bytes) : _bytes = Uint8List.fromList(bytes);

  bool get isDestroyed => _destroyed;

  /// The key bytes. Do not keep a reference beyond the current operation.
  Uint8List get bytes {
    if (_destroyed) {
      throw const DatabaseLockedException();
    }
    return _bytes;
  }

  void destroy() {
    zeroBytes(_bytes);
    _destroyed = true;
  }
}

class SessionState {
  final DatabaseKey? key;

  const SessionState.locked() : key = null;
  const SessionState.unlocked(DatabaseKey this.key);

  bool get isUnlocked => key != null && !key!.isDestroyed;
}

/// Whether the database is open, for services that need it (sync).
///
/// Not the app lock: the app lock only gates the UI
/// ([AuthState.isAuthenticated]); the database stays open behind it.
enum AppLockState { locked, unlocked }

/// Owns the data key. [databaseProvider] watches it: [open] opens a
/// connection keyed with it, [close] closes that connection and zeroes the
/// key. The session is opened at start-up with the key from
/// [DeviceKeyStore] and closed only for a factory reset or a new key.
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    ref.onDispose(() => state.key?.destroy());
    return const SessionState.locked();
  }

  /// Starts a session with [dek] (copied; the caller zeroes its own copy).
  void open(Uint8List dek) {
    final previous = state.key;
    state = SessionState.unlocked(DatabaseKey(dek));
    previous?.destroy();
  }

  /// Closes the database, zeroes the key and emits [AppLockState.locked].
  Future<void> close() async {
    final key = state.key;
    final db = ref.exists(databaseProvider) && key != null
        ? _currentDatabase()
        : null;
    state = const SessionState.locked();
    if (db != null) {
      await closeDatabaseOnce(db);
    }
    key?.destroy();
  }

  AppDatabase? _currentDatabase() {
    try {
      return ref.read(databaseProvider);
    } catch (_) {
      return null;
    }
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// Database open/closed state for other services.
///
/// Sync listens to this and pauses on [AppLockState.locked]:
/// `ref.listen(appLockStateProvider, (_, next) { ... })`. While closed any
/// query throws [DatabaseLockedException].
final appLockStateProvider = Provider<AppLockState>((ref) {
  final unlocked = ref.watch(sessionProvider.select((s) => s.isUnlocked));
  return unlocked ? AppLockState.unlocked : AppLockState.locked;
});

final secureStoreProvider = Provider<SecureStore>(
  (ref) => FlutterSecureStore.current(),
);

final legacySecureStoreProvider = Provider<SecureStore>(
  (ref) => FlutterSecureStore.legacy(),
);

final deviceKeyStoreProvider = Provider<DeviceKeyStore>(
  (ref) => DeviceKeyStore(ref.watch(secureStoreProvider)),
);

/// The master-password vault of installs from before [DeviceKeyStore];
/// read once to move the key there (legacy unlock screen).
final keyVaultProvider = Provider<KeyVault>(
  (ref) => KeyVault(ref.watch(secureStoreProvider)),
);

final legacyKeyMaterialProvider = Provider<LegacyKeyMaterial>(
  (ref) => LegacyKeyMaterial(ref.watch(legacySecureStoreProvider)),
);

final biometricKeyStoreProvider = Provider<BiometricKeyStore>(
  (ref) => const PlatformBiometricKeyStore(),
);

final unlockServiceProvider = Provider<UnlockService>((ref) {
  return UnlockService(
    vault: ref.watch(keyVaultProvider),
    legacy: ref.watch(legacyKeyMaterialProvider),
    biometrics: ref.watch(biometricKeyStoreProvider),
    databaseFile: databaseFile,
  );
});

final legacyKeyMigrationProvider = Provider<LegacyKeyMigration>((ref) {
  return LegacyKeyMigration(
    deviceKeys: ref.watch(deviceKeyStoreProvider),
    vault: ref.watch(keyVaultProvider),
    legacy: ref.watch(legacyKeyMaterialProvider),
    biometrics: ref.watch(biometricKeyStoreProvider),
  );
});
