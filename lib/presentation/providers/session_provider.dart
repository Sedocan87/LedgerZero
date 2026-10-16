import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/data/database/connection.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/services/security/biometric_key_store.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:ledger_zero/services/security/key_vault.dart';
import 'package:ledger_zero/services/security/legacy_key_material.dart';
import 'package:ledger_zero/services/security/secure_store.dart';
import 'package:ledger_zero/services/security/unlock_service.dart';

/// Reading the database while the app is locked.
class DatabaseLockedException implements Exception {
  const DatabaseLockedException();
  @override
  String toString() => 'DatabaseLockedException: the app is locked';
}

/// The unlocked data key. Owned by [SessionController]; zeroed on lock.
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

/// Whether the app is unlocked, for services that must stop while locked.
enum AppLockState { locked, unlocked }

/// Owns the unlocked data key. [databaseProvider] watches it: unlocking
/// opens a connection keyed with it, locking closes that connection and
/// zeroes the key.
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    ref.onDispose(() => state.key?.destroy());
    return const SessionState.locked();
  }

  /// Starts a session with [dek] (copied; the caller zeroes its own copy).
  void unlock(Uint8List dek) {
    final previous = state.key;
    state = SessionState.unlocked(DatabaseKey(dek));
    previous?.destroy();
    ref.read(authProvider.notifier).setAuthenticated(true);
  }

  /// Closes the database, zeroes the key and emits [AppLockState.locked].
  Future<void> lock() async {
    final key = state.key;
    final db = ref.exists(databaseProvider) && key != null
        ? _currentDatabase()
        : null;
    state = const SessionState.locked();
    ref.read(authProvider.notifier).setAuthenticated(false);
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

/// Locked/unlocked state for other services.
///
/// Sync (WP4) must listen to this and pause on [AppLockState.locked]:
/// `ref.listen(appLockStateProvider, (_, next) { ... })`. After a lock the
/// database connection is closed, so any further query throws
/// [DatabaseLockedException].
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
