import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:ledger_zero/services/security/secure_store.dart';
import 'package:pointycastle/export.dart';

/// Key material written by the pre-v2 design, read only to migrate it.
///
/// That design derived the database passphrase as
/// `base64url(PBKDF2-HMAC-SHA256(password, utf8(salt), 100000, 32))`, stored
/// `salt` and `base64url(SHA-256(passphrase))` as a verifier, keyed the
/// database with `PRAGMA key = '<passphrase>'`, and, with biometrics on,
/// stored the passphrase itself under `db_encryption_key`.
class LegacyKeyMaterial {
  static const String keyEntry = 'db_encryption_key';
  static const String saltEntry = 'db_encryption_salt';
  static const String verifierEntry = 'db_encryption_verifier';
  static const int iterations = 100000;

  final SecureStore _store;

  const LegacyKeyMaterial(this._store);

  Future<String?> salt() => _store.read(saltEntry);

  /// Raw read of a legacy entry (to detect the plaintext biometric copy).
  Future<String?> read(String entry) => _store.read(entry);

  Future<bool> exists() async => (await salt()) != null;

  /// Derives the legacy SQLCipher passphrase (in a background isolate).
  Future<String> derivePassphrase(String password, String salt) {
    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    final saltBytes = Uint8List.fromList(utf8.encode(salt));
    return Isolate.run(() {
      final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
        ..init(Pbkdf2Parameters(saltBytes, iterations, 32));
      final key = derivator.process(passwordBytes);
      zeroBytes(passwordBytes);
      return base64Url.encode(key);
    });
  }

  /// Whether [passphrase] matches the stored verifier. Returns null when no
  /// verifier exists; the caller must then prove the key by opening the
  /// database.
  Future<bool?> matchesVerifier(String passphrase) async {
    final stored = await _store.read(verifierEntry);
    if (stored == null) {
      return null;
    }
    final digest = SHA256Digest().process(
      Uint8List.fromList(utf8.encode(passphrase)),
    );
    return constantTimeEquals(
      utf8.encode(base64Url.encode(digest)),
      utf8.encode(stored),
    );
  }

  /// Removes every legacy entry, including a plaintext biometric copy.
  Future<void> deleteAll() async {
    await _store.delete(keyEntry);
    await _store.delete(saltEntry);
    await _store.delete(verifierEntry);
  }
}
