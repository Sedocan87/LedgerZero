import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal key-value interface over the platform keystore, so the code that
/// uses it can be tested with an in-memory fake.
///
/// Holds two secrets: the password of the automatic backups and the Wi-Fi
/// sync pairing. Both can be entered again, so losing them never blocks the
/// app: the user re-enters the backup password or pairs again. (The
/// database is not here: it is a plain file in the app's private storage.)
abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureStore implements SecureStore {
  final FlutterSecureStorage _storage;

  const FlutterSecureStore(this._storage);

  /// Android: AES-GCM data with a KeyStore-held wrapping key. Its files are
  /// never backed up or moved to a new phone (the KeyStore key cannot go
  /// along; see android/app/src/main/res/xml/data_extraction_rules.xml).
  /// `resetOnError`: when the KeyStore key is gone (some vendors wipe it on
  /// a screen lock change), the unreadable entries are deleted and read as
  /// missing instead of failing every time.
  factory FlutterSecureStore.current() => const FlutterSecureStore(
    FlutterSecureStorage(aOptions: AndroidOptions(resetOnError: true)),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
