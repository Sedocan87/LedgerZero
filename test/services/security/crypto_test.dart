import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/security/crypto/aead.dart';
import 'package:ledger_zero/services/security/crypto/kdf.dart';
import 'package:ledger_zero/services/security/crypto/recovery_key.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('Argon2id', () {
    test('matches the reference implementation test vector', () {
      // phc-winner-argon2 test.c: argon2id v1.3, t=2, m=2^16 KiB, p=1.
      final key = deriveKeySync(
        Uint8List.fromList(utf8.encode('password')),
        KdfParams.argon2id(
          salt: Uint8List.fromList(utf8.encode('somesalt')),
          memoryKiB: 1 << 16,
          iterations: 2,
          parallelism: 1,
        ),
      );
      expect(
        _hex(key),
        '09316115d5cf24ed5a15a31a3ba326e5cf32edc24702987c02b6566f61913cf7',
      );
    });

    test('default parameters are above the OWASP minimum', () {
      final params = KdfParams.recommended();
      expect(params.algorithm, KdfAlgorithm.argon2id);
      expect(params.memoryKiB, greaterThanOrEqualTo(19 * 1024));
      expect(params.iterations, greaterThanOrEqualTo(2));
      expect(params.salt.length, 16);
    });
  });

  group('PBKDF2-HMAC-SHA256', () {
    test('matches a reference vector (Python hashlib.pbkdf2_hmac)', () {
      final key = deriveKeySync(
        Uint8List.fromList(utf8.encode('passwordPASSWORDpassword')),
        KdfParams.pbkdf2(
          salt: Uint8List.fromList(
            utf8.encode('saltSALTsaltSALTsaltSALTsaltSALTsalt'),
          ),
          iterations: 4096,
        ),
      );
      expect(
        _hex(key),
        '348c89dbcbd32b2f32d814b8116e84cf2b17347ebc1800181c4e2a1fb8dd53e1',
      );
    });
  });

  group('KdfParams', () {
    test('round-trips through JSON', () {
      final params = KdfParams.argon2id(memoryKiB: 1024, iterations: 3);
      final copy = KdfParams.fromJson(
        jsonDecode(jsonEncode(params.toJson())) as Map<String, dynamic>,
      );
      expect(copy.algorithm, KdfAlgorithm.argon2id);
      expect(copy.memoryKiB, 1024);
      expect(copy.iterations, 3);
      expect(copy.salt, params.salt);
    });

    test('rejects out-of-range values from untrusted input', () {
      final json = KdfParams.argon2id().toJson()..['m'] = 1 << 30;
      expect(
        () => KdfParams.fromJson(json),
        throwsA(isA<KdfParamsException>()),
      );
      expect(
        () => KdfParams.fromJson({'alg': 'md5', 'salt': 'AAAAAAAAAAA='}),
        throwsA(isA<KdfParamsException>()),
      );
    });

    test('derives in a background isolate', () async {
      final params = KdfParams.argon2id(memoryKiB: 64, iterations: 1);
      final a = await deriveKey('secret', params);
      final b = deriveKeySync(
        Uint8List.fromList(utf8.encode('secret')),
        params,
      );
      expect(a, b);
    });
  });

  group('AES-256-GCM', () {
    final key = secureRandomBytes(32);

    test('round-trips with associated data', () {
      final nonce = AesGcm.randomNonce();
      final aad = Uint8List.fromList([1, 2, 3]);
      final ct = AesGcm.encrypt(
        key: key,
        nonce: nonce,
        plaintext: Uint8List.fromList(utf8.encode('hello')),
        aad: aad,
      );
      expect(
        utf8.decode(
          AesGcm.decrypt(key: key, nonce: nonce, ciphertext: ct, aad: aad),
        ),
        'hello',
      );
    });

    test('detects tampering, wrong key and wrong associated data', () {
      final nonce = AesGcm.randomNonce();
      final ct = AesGcm.encrypt(
        key: key,
        nonce: nonce,
        plaintext: Uint8List.fromList(utf8.encode('hello')),
      );
      final tampered = Uint8List.fromList(ct)..[0] ^= 1;
      expect(
        () => AesGcm.decrypt(key: key, nonce: nonce, ciphertext: tampered),
        throwsA(isA<AeadAuthenticationException>()),
      );
      expect(
        () => AesGcm.decrypt(
          key: secureRandomBytes(32),
          nonce: nonce,
          ciphertext: ct,
        ),
        throwsA(isA<AeadAuthenticationException>()),
      );
      expect(
        () => AesGcm.decrypt(
          key: key,
          nonce: nonce,
          ciphertext: ct,
          aad: Uint8List.fromList([9]),
        ),
        throwsA(isA<AeadAuthenticationException>()),
      );
    });
  });

  group('RecoveryKey', () {
    test('has at least 128 bits and is shown in groups of four', () {
      final key = RecoveryKey.generate();
      expect(key.bytes.length * 8, greaterThanOrEqualTo(128));
      final text = key.format();
      expect(text, matches(RegExp(r'^([0-9A-Z]{4}-){7}[0-9A-Z]{4}$')));
    });

    test('parses back tolerating case, spaces, dashes and look-alikes', () {
      final key = RecoveryKey.generate();
      final text = key.format();
      expect(RecoveryKey.tryParse(text)!.bytes, key.bytes);
      expect(
        RecoveryKey.tryParse(
          '  ${text.toLowerCase().replaceAll('-', ' ')}\n',
        )!.bytes,
        key.bytes,
      );
      final lookAlikes = text.replaceAll('0', 'O').replaceAll('1', 'l');
      expect(RecoveryKey.tryParse(lookAlikes)!.bytes, key.bytes);
    });

    test('rejects malformed input', () {
      expect(RecoveryKey.tryParse(''), isNull);
      expect(RecoveryKey.tryParse('ABCD-EFGH'), isNull);
      expect(RecoveryKey.tryParse('U' * 32), isNull);
    });
  });
}
