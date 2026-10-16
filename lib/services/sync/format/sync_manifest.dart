import 'dart:convert';
import 'dart:typed_data';

import 'package:ledger_zero/services/security/crypto/aead.dart';
import 'package:ledger_zero/services/security/crypto/kdf.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:uuid/uuid.dart';

/// The sync passphrase does not match the sync folder's manifest.
class WrongSyncPassphraseException implements Exception {
  const WrongSyncPassphraseException();
  @override
  String toString() => 'WrongSyncPassphraseException';
}

/// The manifest file is missing fields, has an unknown format or unsafe KDF
/// parameters.
class InvalidSyncManifestException implements Exception {
  final String message;
  const InvalidSyncManifestException(this.message);
  @override
  String toString() => 'InvalidSyncManifestException: $message';
}

/// `ledgerzero-sync-manifest.json` in the sync folder.
///
/// Holds everything needed to derive the sync key from the passphrase (KDF
/// parameters and salt), a random [syncId] naming this sync set, and a key
/// check value: a known constant encrypted with the derived key. A wrong
/// passphrase fails the check. The manifest is not secret.
class SyncManifest {
  static const String format = 'ledgerzero-sync';
  static const int version = 2;
  static const String _checkPlaintext = 'ledgerzero-sync-key-check-v2';

  final String syncId;
  final KdfParams kdf;
  final Uint8List checkNonce;
  final Uint8List checkCiphertext;
  final DateTime createdAt;

  const SyncManifest._({
    required this.syncId,
    required this.kdf,
    required this.checkNonce,
    required this.checkCiphertext,
    required this.createdAt,
  });

  /// Creates a manifest for a new sync folder and returns it with the
  /// derived sync key. [kdf] defaults to the app's Argon2id parameters.
  static Future<(SyncManifest, Uint8List)> create(
    String passphrase, {
    KdfParams? kdf,
    DateTime? now,
  }) async {
    final params = kdf ?? KdfParams.recommended();
    final syncId = const Uuid().v4();
    final key = await _deriveSyncKey(passphrase, params, syncId);
    final nonce = AesGcm.randomNonce();
    final check = AesGcm.encrypt(
      key: key,
      nonce: nonce,
      plaintext: Uint8List.fromList(utf8.encode(_checkPlaintext)),
      aad: _checkAad(syncId, params),
    );
    return (
      SyncManifest._(
        syncId: syncId,
        kdf: params,
        checkNonce: nonce,
        checkCiphertext: check,
        createdAt: (now ?? DateTime.now()).toUtc(),
      ),
      key,
    );
  }

  /// Derives the sync key from [passphrase]. Throws
  /// [WrongSyncPassphraseException] if the key check fails.
  Future<Uint8List> unlock(String passphrase) async {
    final key = await _deriveSyncKey(passphrase, kdf, syncId);
    if (!verifyKey(key)) {
      zeroBytes(key);
      throw const WrongSyncPassphraseException();
    }
    return key;
  }

  /// Whether [key] is this manifest's sync key.
  bool verifyKey(Uint8List key) {
    if (key.length != AesGcm.keyLength) {
      return false;
    }
    try {
      final plain = AesGcm.decrypt(
        key: key,
        nonce: checkNonce,
        ciphertext: checkCiphertext,
        aad: _checkAad(syncId, kdf),
      );
      return utf8.decode(plain) == _checkPlaintext;
    } on AeadAuthenticationException {
      return false;
    }
  }

  Uint8List toBytes() => Uint8List.fromList(
    utf8.encode(
      const JsonEncoder.withIndent('  ').convert({
        'format': format,
        'version': version,
        'syncId': syncId,
        'kdf': kdf.toJson(),
        'keyCheck': {
          'nonce': base64.encode(checkNonce),
          'ciphertext': base64.encode(checkCiphertext),
        },
        'createdAt': createdAt.toIso8601String(),
      }),
    ),
  );

  factory SyncManifest.fromBytes(List<int> bytes) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const InvalidSyncManifestException('not JSON');
    }
    if (json is! Map<String, dynamic> || json['format'] != format) {
      throw const InvalidSyncManifestException('not a LedgerZero manifest');
    }
    if (json['version'] != version) {
      throw InvalidSyncManifestException(
        'unsupported version ${json['version']}',
      );
    }
    try {
      final syncId = json['syncId'] as String;
      if (!RegExp(r'^[0-9a-f-]{36}$').hasMatch(syncId)) {
        throw const InvalidSyncManifestException('invalid sync id');
      }
      final check = json['keyCheck'] as Map<String, dynamic>;
      final nonce = base64.decode(check['nonce'] as String);
      if (nonce.length != AesGcm.nonceLength) {
        throw const InvalidSyncManifestException('invalid nonce');
      }
      return SyncManifest._(
        syncId: syncId,
        kdf: KdfParams.fromJson(json['kdf'] as Map<String, dynamic>),
        checkNonce: nonce,
        checkCiphertext: base64.decode(check['ciphertext'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      );
    } on InvalidSyncManifestException {
      rethrow;
    } on KdfParamsException catch (e) {
      throw InvalidSyncManifestException(e.message);
    } catch (_) {
      throw const InvalidSyncManifestException('malformed manifest');
    }
  }

  static Uint8List _checkAad(String syncId, KdfParams kdf) =>
      Uint8List.fromList([
        ...utf8.encode('ledgerzero-sync-manifest-v2|$syncId|'),
        ...kdf.canonicalBytes(),
      ]);

  /// Passphrase -> Argon2id (manifest parameters) -> HKDF-SHA256 with the
  /// sync id, so the file key is bound to this sync set.
  static Future<Uint8List> _deriveSyncKey(
    String passphrase,
    KdfParams kdf,
    String syncId,
  ) async {
    final master = await deriveKey(passphrase, kdf);
    try {
      return hkdfSha256(
        ikm: master,
        salt: Uint8List.fromList(utf8.encode(syncId)),
        info: Uint8List.fromList(utf8.encode('ledgerzero-sync-v2 file key')),
      );
    } finally {
      zeroBytes(master);
    }
  }
}
