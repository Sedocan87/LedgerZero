import 'dart:typed_data';

import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:pointycastle/export.dart';

/// Thrown when AES-GCM authentication fails: wrong key, or the data or its
/// associated data was modified.
class AeadAuthenticationException implements Exception {
  const AeadAuthenticationException();

  @override
  String toString() => 'AeadAuthenticationException: authentication failed';
}

/// AES-256-GCM with a 96-bit nonce and a 128-bit tag.
class AesGcm {
  AesGcm._();

  static const int keyLength = 32;
  static const int nonceLength = 12;
  static const int tagLength = 16;

  /// Encrypts [plaintext] and returns ciphertext followed by the tag.
  static Uint8List encrypt({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List plaintext,
    Uint8List? aad,
  }) {
    _check(key, nonce);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key),
          tagLength * 8,
          nonce,
          aad ?? Uint8List(0),
        ),
      );
    return cipher.process(plaintext);
  }

  /// Decrypts ciphertext+tag produced by [encrypt].
  ///
  /// Throws [AeadAuthenticationException] if the tag does not verify.
  static Uint8List decrypt({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List ciphertext,
    Uint8List? aad,
  }) {
    _check(key, nonce);
    if (ciphertext.length < tagLength) {
      throw const AeadAuthenticationException();
    }
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(key),
          tagLength * 8,
          nonce,
          aad ?? Uint8List(0),
        ),
      );
    try {
      return cipher.process(ciphertext);
    } on InvalidCipherTextException {
      throw const AeadAuthenticationException();
    } on ArgumentError {
      throw const AeadAuthenticationException();
    }
  }

  /// A fresh random nonce. Only safe because every key we use encrypts a
  /// small number of messages (random 96-bit nonces are fine up to ~2^32).
  static Uint8List randomNonce() => secureRandomBytes(nonceLength);

  static void _check(Uint8List key, Uint8List nonce) {
    if (key.length != keyLength) {
      throw ArgumentError('AES-256-GCM needs a 32-byte key');
    }
    if (nonce.length != nonceLength) {
      throw ArgumentError('AES-GCM needs a 12-byte nonce');
    }
  }
}

/// HKDF-SHA256 (RFC 5869).
Uint8List hkdfSha256({
  required Uint8List ikm,
  required Uint8List salt,
  required Uint8List info,
  int length = 32,
}) {
  final hkdf = HKDFKeyDerivator(SHA256Digest())
    ..init(HkdfParameters(ikm, length, salt, info));
  final out = Uint8List(length);
  hkdf.deriveKey(null, 0, out, 0);
  return out;
}
