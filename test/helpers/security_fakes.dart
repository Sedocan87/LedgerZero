import 'package:ledger_zero/services/security/app_lock_authenticator.dart';
import 'package:ledger_zero/services/security/crypto/kdf.dart';
import 'package:ledger_zero/services/security/secure_store.dart';

/// Cheap Argon2id parameters so tests do not spend ~1 s per derivation.
KdfParams fastKdf() => KdfParams.argon2id(memoryKiB: 64, iterations: 1);

/// In-memory [SecureStore].
class InMemorySecureStore implements SecureStore {
  final Map<String, String> values;

  InMemorySecureStore([Map<String, String>? initial]) : values = {...?initial};

  /// Number of write calls, to assert single-write updates.
  int writeCount = 0;

  /// Reads throw this, like a KeyStore whose key is gone.
  Object? readError;

  @override
  Future<String?> read(String key) async {
    final error = readError;
    if (error != null) {
      throw error;
    }
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writeCount++;
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

/// [AppLockAuthenticator] with a scripted outcome.
class FakeAppLockAuthenticator implements AppLockAuthenticator {
  FakeAppLockAuthenticator({
    this.screenLock = true,
    this.result = AppLockResult.success,
  });

  bool screenLock;
  AppLockResult result;
  int prompts = 0;

  @override
  String? lastFailure;

  @override
  Future<bool> canAuthenticate() async => screenLock;

  @override
  Future<AppLockResult> authenticate({
    required String title,
    String? subtitle,
  }) async {
    prompts++;
    return screenLock ? result : AppLockResult.unavailable;
  }
}
