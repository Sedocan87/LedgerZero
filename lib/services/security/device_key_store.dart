import 'dart:convert';
import 'dart:typed_data';

import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:ledger_zero/services/security/secure_store.dart';

/// Holds the database key (DEK) protected by the Android KeyStore.
///
/// The DEK is a random 256-bit key generated at onboarding. It is stored in
/// [SecureStore] (flutter_secure_storage: AES-GCM with a KeyStore-held
/// wrapping key that needs no user authentication), so the database can be
/// opened whenever the app runs, also while the app lock is showing and for
/// background work. The app lock gates the UI, not the key.
///
/// Installs from before this design kept the DEK wrapped by the master
/// password ([KeyVault]); they move it here once (see the legacy unlock
/// screen).
class DeviceKeyStore {
  const DeviceKeyStore(this._store);

  final SecureStore _store;

  static const String storageKey = 'lz_device_dek_v1';
  static const int keyLength = 32;

  /// The stored DEK, or `null` when none is stored.
  Future<Uint8List?> read() async {
    final value = await _store.read(storageKey);
    if (value == null) {
      return null;
    }
    final bytes = base64Decode(value);
    if (bytes.length != keyLength) {
      throw const FormatException('Stored database key has a wrong length');
    }
    return bytes;
  }

  /// Generates, stores and returns a new DEK.
  Future<Uint8List> create() async {
    final dek = secureRandomBytes(keyLength);
    await write(dek);
    return dek;
  }

  Future<void> write(Uint8List dek) async {
    if (dek.length != keyLength) {
      throw ArgumentError.value(dek.length, 'dek.length');
    }
    await _store.write(storageKey, base64Encode(dek));
  }

  Future<void> delete() => _store.delete(storageKey);
}
