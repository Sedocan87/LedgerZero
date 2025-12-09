import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pointycastle/export.dart';

class SecurityManager {
  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  // Static session key to be used by the database connection
  static String? _sessionKey;
  static String? get sessionKey => _sessionKey;
  static void setSessionKey(String? key) {
    _sessionKey = key;
  }

  SecurityManager({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            ),
        _localAuth = localAuth ?? LocalAuthentication();

  static const _keyStorageKey = 'db_encryption_key';
  static const _saltStorageKey = 'db_encryption_salt';
  static const _verifierStorageKey = 'db_encryption_verifier';

  /// Generates a cryptographically secure random key.
  ///
  /// The key is 256 bits (32 bytes) long and is returned as a Base64 encoded string.
  /// This is suitable for use as an SQLCipher encryption key (AES-256).
  String generateSecureKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  /// Derives a 256-bit (32-byte) key from a password and salt using PBKDF2.
  ///
  /// [password] The user's password.
  /// [salt] A random salt (should be stored alongside the derived key).
  /// [iterations] Number of iterations (default 100,000).
  ///
  /// Returns a Base64 encoded string of the derived key.
  String deriveKeyFromPassword(String password, String salt,
      {int iterations = 100000}) {
    final pkcs = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    final saltBytes = Uint8List.fromList(utf8.encode(salt));

    pkcs.init(Pbkdf2Parameters(saltBytes, iterations, 32));

    final keyBytes = pkcs.process(Uint8List.fromList(utf8.encode(password)));
    return base64Url.encode(keyBytes);
  }

  /// Stores the encryption key securely.
  ///
  /// This is typically used when biometric authentication is enabled,
  /// allowing the key to be retrieved without the user entering a password.
  Future<void> storeKey(String key) async {
    await _storage.write(key: _keyStorageKey, value: key);
  }

  /// Retrieves the stored encryption key.
  Future<String?> getKey() async {
    return await _storage.read(key: _keyStorageKey);
  }

  /// Checks if an encryption key is stored.
  Future<bool> hasKey() async {
    final key = await _storage.read(key: _keyStorageKey);
    return key != null;
  }

  /// Deletes the stored encryption key.
  Future<void> clearKey() async {
    await _storage.delete(key: _keyStorageKey);
  }

  /// Stores the salt used for password-based key derivation.
  Future<void> storeSalt(String salt) async {
    await _storage.write(key: _saltStorageKey, value: salt);
  }

  /// Retrieves the stored salt.
  Future<String?> getSalt() async {
    return await _storage.read(key: _saltStorageKey);
  }

  /// Stores a hash of the key to verify it later.
  Future<void> storeVerifier(String key) async {
    final bytes = utf8.encode(key);
    final digest = SHA256Digest().process(Uint8List.fromList(bytes));
    final hash = base64Url.encode(digest);
    await _storage.write(key: _verifierStorageKey, value: hash);
  }

  /// Verifies if the provided key matches the stored verifier.
  Future<bool> verifyKey(String key) async {
    final stored = await _storage.read(key: _verifierStorageKey);
    if (stored == null) {
      return true; // No verifier, can't verify (assume valid or handle elsewhere)
    }

    final bytes = utf8.encode(key);
    final digest = SHA256Digest().process(Uint8List.fromList(bytes));
    final hash = base64Url.encode(digest);

    return stored == hash;
  }

  /// Deletes all security related data.
  Future<void> clearAll() async {
    await _storage.delete(key: _keyStorageKey);
    await _storage.delete(key: _saltStorageKey);
    await _storage.delete(key: _verifierStorageKey);
  }

  /// Checks if biometric authentication is available on the device.
  Future<bool> get isBiometricsAvailable async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Authenticates the user using biometrics.
  ///
  /// Returns `true` if authentication is successful, `false` otherwise.
  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access your financial data',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
