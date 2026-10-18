import 'dart:typed_data';

import 'package:ledger_zero/services/security/app_lock_authenticator.dart';
import 'package:ledger_zero/services/security/biometric_key_store.dart';
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

  @override
  Future<String?> read(String key) async => values[key];

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

/// [BiometricKeyStore] that keeps the secret in memory and can be told to
/// fail like the platform would.
class FakeBiometricKeyStore implements BiometricKeyStore {
  Uint8List? secret;
  bool available;
  BiometricFailure? failNextReadWith;
  int deleteCount = 0;

  FakeBiometricKeyStore({this.available = true});

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> hasKey() async => secret != null;

  @override
  Future<Uint8List> read(BiometricPromptTexts texts) async {
    final failure = failNextReadWith;
    if (failure != null) {
      failNextReadWith = null;
      throw BiometricException(failure);
    }
    final value = secret;
    if (value == null) {
      throw const BiometricException(BiometricFailure.notFound);
    }
    return Uint8List.fromList(value);
  }

  @override
  Future<void> delete() async {
    deleteCount++;
    secret = null;
  }
}

const testPromptTexts = BiometricPromptTexts(
  title: 'Unlock',
  subtitle: 'Confirm',
  cancel: 'Cancel',
);

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
