import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:ledger_zero/core/constants/app_constants.dart';
import 'package:ledger_zero/data/database/sqlcipher.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The encrypted database file.
Future<File> databaseFile() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  return File(p.join(dbFolder.path, AppConstants.databaseFilename));
}

/// Deletes the database file together with its WAL and shared-memory files.
///
/// Close every connection to the database before calling this.
Future<void> deleteDatabaseFiles() async {
  final file = await databaseFile();
  for (final suffix in const ['', '-wal', '-shm']) {
    final f = File('${file.path}$suffix');
    if (await f.exists()) {
      await f.delete();
    }
  }
}

/// Opens the app database keyed with the raw 256-bit data key [dek].
///
/// Fails closed: if SQLCipher is not linked, or the key does not open the
/// file, the first query throws [EncryptionUnavailableException] or
/// [DatabaseKeyException] instead of opening or creating an unkeyed
/// database. The key bytes are copied; the caller may zero its own copy.
QueryExecutor openEncryptedConnection(Uint8List dek, {File? file}) {
  // Validates the length now, on the caller's stack.
  final key = RawSqlCipherKey(Uint8List.fromList(dek));
  return LazyDatabase(() async {
    final target = file ?? await databaseFile();
    return NativeDatabase(
      target,
      setup: (db) {
        try {
          SqlCipher.applyKey(db, key);
        } finally {
          // SQLCipher keeps its own copy for the life of the connection.
          zeroBytes(key.bytes);
        }
      },
    );
  });
}
