import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal key-value interface over the platform keystore, so key logic can
/// be tested with an in-memory fake.
///
/// Only wrapped (encrypted) key blobs and non-secret metadata are stored
/// here. Never a plaintext database key.
abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureStore implements SecureStore {
  final FlutterSecureStorage _storage;

  const FlutterSecureStore(this._storage);

  /// Storage for everything written by the current key design.
  ///
  /// iOS: keychain items readable after first unlock, never migrated to
  /// another device or included in unencrypted backups (`ThisDeviceOnly`).
  /// Android: AES-GCM data with a KeyStore-held RSA-OAEP wrapping key
  /// (flutter_secure_storage v10). `resetOnError: false` so a keystore error
  /// is reported instead of silently erasing the wrapped key.
  factory FlutterSecureStore.current() => const FlutterSecureStore(
    FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError: false),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
        synchronizable: false,
      ),
    ),
  );

  /// Storage as written by the pre-v2 design, used only to read and then
  /// delete legacy entries. On iOS the keychain query includes the
  /// accessibility class, so legacy items are only found with the old one.
  /// On Android v10 migrates the old EncryptedSharedPreferences data on
  /// first access.
  factory FlutterSecureStore.legacy() => const FlutterSecureStore(
    FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError: false),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
