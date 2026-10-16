import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart' as sqlite;

/// The database could not be opened with the key it was given: wrong key,
/// no key, or not a database.
class DatabaseKeyException implements Exception {
  final String message;
  const DatabaseKeyException(this.message);
  @override
  String toString() => 'DatabaseKeyException: $message';
}

/// The linked SQLite library has no SQLCipher. Opening would silently write
/// plaintext, so we refuse.
class EncryptionUnavailableException implements Exception {
  const EncryptionUnavailableException();
  @override
  String toString() =>
      'EncryptionUnavailableException: SQLCipher is not available';
}

/// A key as given to SQLCipher.
sealed class SqlCipherKey {
  const SqlCipherKey();

  /// The right-hand side of `PRAGMA key = ...` / `KEY ...` in ATTACH.
  String get sqlLiteral;
}

/// A raw 256-bit key, passed as `"x'<64 hex>'"`: SQLCipher uses it directly
/// (no PBKDF2 of its own on top).
class RawSqlCipherKey extends SqlCipherKey {
  final Uint8List bytes;

  RawSqlCipherKey(this.bytes) {
    if (bytes.length != 32) {
      throw const DatabaseKeyException('raw key must be 32 bytes');
    }
  }

  @override
  String get sqlLiteral {
    final hex = StringBuffer();
    for (final b in bytes) {
      hex.write(b.toRadixString(16).padLeft(2, '0'));
    }
    // Only [0-9a-f] can appear, so interpolation cannot inject SQL.
    return '"x\'$hex\'"';
  }
}

/// A passphrase key as written by the pre-v2 design (base64url of a PBKDF2
/// output). SQLCipher runs its own KDF over it. Only used to open a legacy
/// database once, to re-key it.
class LegacyPassphraseKey extends SqlCipherKey {
  static final RegExp _allowed = RegExp(r'^[A-Za-z0-9_\-=+/]+$');
  final String passphrase;

  LegacyPassphraseKey(this.passphrase) {
    if (!_allowed.hasMatch(passphrase)) {
      throw const DatabaseKeyException('unexpected legacy key format');
    }
  }

  @override
  String get sqlLiteral => "'$passphrase'";
}

/// Thin helpers around SQLCipher pragmas, shared by the app connection,
/// backup/restore and the legacy migration.
class SqlCipher {
  SqlCipher._();

  /// Whether the loaded library is SQLCipher.
  static bool isAvailable(sqlite.Database db) {
    try {
      final rows = db.select('PRAGMA cipher_version');
      return rows.isNotEmpty &&
          (rows.first.values.first as String?)?.isNotEmpty == true;
    } catch (_) {
      return false;
    }
  }

  /// Keys [db] and proves the key works by reading the schema. Throws
  /// [EncryptionUnavailableException] or [DatabaseKeyException]; never
  /// leaves an unkeyed connection behind for the caller to use.
  static void applyKey(sqlite.Database db, SqlCipherKey key) {
    if (!isAvailable(db)) {
      throw const EncryptionUnavailableException();
    }
    db.execute('PRAGMA key = ${key.sqlLiteral}');
    verifyReadable(db);
  }

  /// Throws [DatabaseKeyException] unless the schema can be read.
  static void verifyReadable(sqlite.Database db) {
    try {
      db.select('SELECT count(*) FROM sqlite_master');
    } on sqlite.SqliteException catch (e) {
      throw DatabaseKeyException('database cannot be read (${e.resultCode})');
    }
  }

  /// Whether [file] opens with [key].
  static bool canOpen(File file, SqlCipherKey key) {
    if (!file.existsSync()) {
      return false;
    }
    final db = sqlite.sqlite3.open(file.path);
    try {
      applyKey(db, key);
      return true;
    } on DatabaseKeyException {
      return false;
    } finally {
      db.close();
    }
  }

  /// Changes the key of [file] from [from] to [to] in place (`PRAGMA
  /// rekey`). Only the one-time legacy migration uses this.
  static void rekey(File file, SqlCipherKey from, RawSqlCipherKey to) {
    final db = sqlite.sqlite3.open(file.path);
    try {
      applyKey(db, from);
      // Fold the WAL into the main file first so every page is rewritten.
      db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
      db.execute('PRAGMA rekey = ${to.sqlLiteral}');
    } finally {
      db.close();
    }
    if (!canOpen(file, to)) {
      throw const DatabaseKeyException('re-keyed database does not open');
    }
  }

  /// Writes a copy of the open, keyed [db] to [target] encrypted with
  /// [targetKey] (null = plaintext) via `sqlcipher_export`. The schema
  /// version (`user_version`) is copied too.
  static void exportTo(
    sqlite.Database db,
    File target,
    RawSqlCipherKey? targetKey,
  ) {
    if (!isAvailable(db)) {
      throw const EncryptionUnavailableException();
    }
    if (target.existsSync()) {
      target.deleteSync();
    }
    final keyLiteral = targetKey?.sqlLiteral ?? "''";
    final userVersion = db.select('PRAGMA user_version').first.values.first;
    db.execute('ATTACH DATABASE ? AS lz_export KEY $keyLiteral', [target.path]);
    try {
      db.select("SELECT sqlcipher_export('lz_export')");
      db.execute('PRAGMA lz_export.user_version = $userVersion');
    } finally {
      db.execute('DETACH DATABASE lz_export');
    }
  }
}
