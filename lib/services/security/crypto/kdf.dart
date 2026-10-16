import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:pointycastle/export.dart';

enum KdfAlgorithm {
  /// Argon2id v1.3 (RFC 9106). The default for new keys.
  argon2id,

  /// PBKDF2-HMAC-SHA256. Read support for old backups; can be chosen for new
  /// keys with >= 600,000 iterations.
  pbkdf2Sha256,
}

/// Thrown when stored KDF parameters are malformed or outside safe bounds.
class KdfParamsException implements Exception {
  final String message;
  const KdfParamsException(this.message);

  @override
  String toString() => 'KdfParamsException: $message';
}

/// A password-based key derivation function with all of its parameters.
///
/// Stored next to every password-protected blob (key vault, backups) so the
/// cost can be raised later without breaking existing data.
class KdfParams {
  final KdfAlgorithm algorithm;
  final Uint8List salt;

  /// Argon2: passes (t). PBKDF2: iterations.
  final int iterations;

  /// Argon2 only: memory in KiB (m).
  final int memoryKiB;

  /// Argon2 only: lanes (p).
  final int parallelism;

  const KdfParams._({
    required this.algorithm,
    required this.salt,
    required this.iterations,
    this.memoryKiB = 0,
    this.parallelism = 0,
  });

  /// Default Argon2id cost: m = 46 MiB, t = 2, p = 1.
  ///
  /// Above the OWASP minimum (m = 19 MiB, t = 2, p = 1). Measured with
  /// pointycastle 4.0.0 in AOT on an Apple M4: ~185 ms; a mid-range phone is
  /// roughly 4-5x slower (~0.8-0.95 s), within the 1.5 s unlock budget.
  /// See docs/ENCRYPTION.md for the benchmark.
  static const int defaultArgon2MemoryKiB = 46 * 1024;
  static const int defaultArgon2Iterations = 2;
  static const int defaultArgon2Parallelism = 1;

  /// Minimum accepted when creating new PBKDF2 parameters (OWASP 2023).
  static const int minPbkdf2Iterations = 600000;

  factory KdfParams.argon2id({
    Uint8List? salt,
    int memoryKiB = defaultArgon2MemoryKiB,
    int iterations = defaultArgon2Iterations,
    int parallelism = defaultArgon2Parallelism,
  }) {
    final params = KdfParams._(
      algorithm: KdfAlgorithm.argon2id,
      salt: salt ?? secureRandomBytes(16),
      iterations: iterations,
      memoryKiB: memoryKiB,
      parallelism: parallelism,
    );
    params.validate();
    return params;
  }

  factory KdfParams.pbkdf2({
    Uint8List? salt,
    int iterations = minPbkdf2Iterations,
  }) {
    final params = KdfParams._(
      algorithm: KdfAlgorithm.pbkdf2Sha256,
      salt: salt ?? secureRandomBytes(16),
      iterations: iterations,
    );
    params.validate();
    return params;
  }

  /// The parameters used for new password-derived keys.
  factory KdfParams.recommended() => KdfParams.argon2id();

  /// Rejects malformed parameters and values large enough to be a
  /// denial-of-service when read from an untrusted file.
  void validate() {
    if (salt.length < 8 || salt.length > 64) {
      throw const KdfParamsException('salt length out of range');
    }
    switch (algorithm) {
      case KdfAlgorithm.argon2id:
        if (iterations < 1 || iterations > 64) {
          throw const KdfParamsException('argon2 iterations out of range');
        }
        if (parallelism < 1 || parallelism > 16) {
          throw const KdfParamsException('argon2 parallelism out of range');
        }
        if (memoryKiB < 8 * parallelism || memoryKiB > 1024 * 1024) {
          throw const KdfParamsException('argon2 memory out of range');
        }
      case KdfAlgorithm.pbkdf2Sha256:
        if (iterations < 1000 || iterations > 50000000) {
          throw const KdfParamsException('pbkdf2 iterations out of range');
        }
    }
  }

  Map<String, Object> toJson() => switch (algorithm) {
    KdfAlgorithm.argon2id => {
      'alg': 'argon2id',
      'v': 0x13,
      'm': memoryKiB,
      't': iterations,
      'p': parallelism,
      'salt': base64.encode(salt),
    },
    KdfAlgorithm.pbkdf2Sha256 => {
      'alg': 'pbkdf2-sha256',
      'i': iterations,
      'salt': base64.encode(salt),
    },
  };

  factory KdfParams.fromJson(Map<String, dynamic> json) {
    try {
      final salt = base64.decode(json['salt'] as String);
      final KdfParams params;
      switch (json['alg']) {
        case 'argon2id':
          if (json['v'] != 0x13) {
            throw const KdfParamsException('unsupported argon2 version');
          }
          params = KdfParams._(
            algorithm: KdfAlgorithm.argon2id,
            salt: salt,
            iterations: json['t'] as int,
            memoryKiB: json['m'] as int,
            parallelism: json['p'] as int,
          );
        case 'pbkdf2-sha256':
          params = KdfParams._(
            algorithm: KdfAlgorithm.pbkdf2Sha256,
            salt: salt,
            iterations: json['i'] as int,
          );
        default:
          throw KdfParamsException('unknown algorithm ${json['alg']}');
      }
      params.validate();
      return params;
    } on KdfParamsException {
      rethrow;
    } catch (e) {
      throw const KdfParamsException('malformed parameters');
    }
  }

  /// Canonical encoding, used as associated data so the parameters cannot be
  /// swapped for weaker ones without the unwrap failing.
  Uint8List canonicalBytes() =>
      Uint8List.fromList(utf8.encode(jsonEncode(toJson())));
}

/// Derives a 32-byte key from [password] in a background isolate.
Future<Uint8List> deriveKey(String password, KdfParams params) {
  final passwordBytes = Uint8List.fromList(utf8.encode(password));
  final json = params.toJson();
  return Isolate.run(() {
    try {
      return deriveKeySync(passwordBytes, KdfParams.fromJson(json));
    } finally {
      zeroBytes(passwordBytes);
    }
  });
}

/// Synchronous derivation. Prefer [deriveKey] on the UI isolate.
Uint8List deriveKeySync(Uint8List password, KdfParams params) {
  params.validate();
  switch (params.algorithm) {
    case KdfAlgorithm.argon2id:
      final generator = Argon2BytesGenerator()
        ..init(
          Argon2Parameters(
            Argon2Parameters.ARGON2_id,
            params.salt,
            desiredKeyLength: 32,
            iterations: params.iterations,
            memory: params.memoryKiB,
            lanes: params.parallelism,
            version: Argon2Parameters.ARGON2_VERSION_13,
          ),
        );
      final out = Uint8List(32);
      generator.deriveKey(password, 0, out, 0);
      return out;
    case KdfAlgorithm.pbkdf2Sha256:
      final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
        ..init(Pbkdf2Parameters(params.salt, params.iterations, 32));
      return derivator.process(password);
  }
}
