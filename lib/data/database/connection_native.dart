import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:ledger_zero/core/constants/app_constants.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/sqlcipher.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The encrypted database file.
Future<File> databaseFile() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  return File(p.join(dbFolder.path, AppConstants.databaseFilename));
}

/// SQLite's companion files of a database file.
const List<String> databaseFileSuffixes = ['', '-wal', '-shm', '-journal'];

/// The files a restore keeps next to the live database while it swaps files
/// (see `RestoreService` and [recoverInterruptedRestore]).
class RestoreFiles {
  RestoreFiles(this.database);

  final File database;

  /// The new database, built and verified before the swap.
  File get staged => File('${database.path}.restore-new');

  /// The live database moved aside during the swap.
  File get previous => File('${database.path}.previous');

  /// Exists from just before the swap until it completed (or was rolled
  /// back). While it exists, the live file may be missing.
  File get marker => File('${database.path}.restoring');

  /// Every file a restore can leave behind, the live database included.
  List<File> get all => [database, staged, previous, marker];
}

/// Deletes the database file together with its WAL and shared-memory files
/// and every file a restore can leave next to it (`.previous`,
/// `.restore-new`, the restore marker).
///
/// Close every connection to the database before calling this.
Future<void> deleteDatabaseFiles([File? file]) async {
  final db = file ?? await databaseFile();
  for (final variant in RestoreFiles(db).all) {
    await deleteDatabaseFileSet(variant);
  }
}

/// Deletes [file] and its SQLite companion files.
Future<void> deleteDatabaseFileSet(File file) async {
  for (final suffix in databaseFileSuffixes) {
    final f = File('${file.path}$suffix');
    if (await f.exists()) {
      await f.delete();
    }
  }
}

/// Moves [from] and its SQLite companion files to [to].
Future<void> moveDatabaseFileSet(File from, File to) async {
  for (final suffix in databaseFileSuffixes) {
    final f = File('${from.path}$suffix');
    if (await f.exists()) {
      await f.rename('${to.path}$suffix');
    }
  }
}

/// What [recoverInterruptedRestore] did.
enum RestoreRecovery {
  /// The live file was readable: the restore had completed (or had not
  /// started moving files); leftovers were removed.
  keptLive,

  /// The live file was missing or unreadable and the staged, verified new
  /// database was moved into place: the restore is complete.
  completedRestore,

  /// Only the previous database was usable: it was moved back.
  rolledBack,
}

/// Finishes a restore that was interrupted (the process was killed) while
/// the database files were being swapped, so the next launch never starts
/// with an empty database while a copy of the data exists.
///
/// Rule, in this order: a live file that opens with [key] is kept; else a
/// staged file (`.restore-new`, verified complete before the swap started)
/// that opens is moved into place; else the previous file (`.previous`)
/// that opens is moved back. Leftovers and the marker are removed
/// afterwards. Without a restore marker nothing is moved: a readable live
/// file only gets its stale copies deleted. Returns null when there was
/// nothing to recover.
Future<RestoreRecovery?> recoverInterruptedRestore(
  File database,
  SqlCipherKey key,
) async {
  final files = RestoreFiles(database);
  final marker = await files.marker.exists();
  final staged = await files.staged.exists();
  final previous = await files.previous.exists();
  if (!marker && !staged && !previous) {
    return null;
  }
  if (await database.exists() && SqlCipher.canOpen(database, key)) {
    await deleteDatabaseFileSet(files.staged);
    await deleteDatabaseFileSet(files.previous);
    await deleteDatabaseFileSet(files.marker);
    if (marker) {
      Logger.warning('Restore: interrupted swap found; live database kept.');
      return RestoreRecovery.keptLive;
    }
    return null;
  }
  if (staged && SqlCipher.canOpen(files.staged, key)) {
    Logger.warning('Restore: interrupted swap found; completing it.');
    await deleteDatabaseFileSet(database);
    await moveDatabaseFileSet(files.staged, database);
    await deleteDatabaseFileSet(files.previous);
    await deleteDatabaseFileSet(files.marker);
    return RestoreRecovery.completedRestore;
  }
  if (previous && SqlCipher.canOpen(files.previous, key)) {
    Logger.warning('Restore: interrupted swap found; rolling it back.');
    await deleteDatabaseFileSet(database);
    await deleteDatabaseFileSet(files.staged);
    await moveDatabaseFileSet(files.previous, database);
    await deleteDatabaseFileSet(files.marker);
    return RestoreRecovery.rolledBack;
  }
  // Nothing usable: leave every file in place.
  Logger.error('Restore: interrupted swap found, no usable copy');
  return null;
}

/// Opens the app database keyed with the raw 256-bit data key [dek].
///
/// Fails closed: if SQLCipher is not linked, or the key does not open the
/// file, the first query throws [EncryptionUnavailableException] or
/// [DatabaseKeyException] instead of opening or creating an unkeyed
/// database. Before opening, an interrupted restore is finished
/// ([recoverInterruptedRestore]), so a fresh database is never created
/// while a previous or staged copy exists. The key bytes are copied; the
/// caller may zero its own copy.
QueryExecutor openEncryptedConnection(Uint8List dek, {File? file}) {
  // Validates the length now, on the caller's stack.
  final key = RawSqlCipherKey(Uint8List.fromList(dek));
  return LazyDatabase(() async {
    final target = file ?? await databaseFile();
    await recoverInterruptedRestore(target, key);
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
