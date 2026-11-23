import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:ledger_zero/core/constants/app_constants.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// The database file: a plain SQLite file in the app's private storage
/// (`app_flutter/` on Android), protected by the app sandbox. Backups and
/// sync files are encrypted; this file is not (docs/SECURITY.md).
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
  /// back). While it exists, the live file may be missing or unverified.
  File get marker => File('${database.path}.restoring');

  static const String phaseSwapping = 'swapping';
  static const String phaseVerified = 'verified';

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
/// Rule, in this order: a live file that opens is kept; else a staged file
/// (`.restore-new`, verified complete before the swap started) that opens
/// is moved into place; else the previous file (`.previous`) that opens is
/// moved back. Leftovers and the marker are removed
/// afterwards. Without a restore marker nothing is moved: a readable live
/// file only gets its stale copies deleted. Returns null when there was
/// nothing to recover.
Future<RestoreRecovery?> recoverInterruptedRestore(File database) async {
  final files = RestoreFiles(database);
  final marker = await files.marker.exists();
  final staged = await files.staged.exists();
  final previous = await files.previous.exists();
  if (!marker && !staged && !previous) {
    return null;
  }
  final markerPhase = marker ? (await files.marker.readAsString()).trim() : '';
  // If the crash occurred after moving the staged file into place but BEFORE
  // verification/migration succeeded (phaseSwapping), check whether the live
  // DB has a valid schema version and core tables; if not, roll back to
  // .previous rather than deleting .previous.
  final liveUsable = await database.exists() && isReadableDatabase(database);
  final liveVerified =
      liveUsable &&
      (markerPhase != RestoreFiles.phaseSwapping ||
          _isVerifiedRestoredDatabase(database));
  if (liveVerified) {
    await deleteDatabaseFileSet(files.staged);
    await deleteDatabaseFileSet(files.previous);
    await deleteDatabaseFileSet(files.marker);
    if (marker) {
      Logger.warning('Restore: interrupted swap found; live database kept.');
      return RestoreRecovery.keptLive;
    }
    return null;
  }
  if (markerPhase == RestoreFiles.phaseSwapping &&
      previous &&
      isReadableDatabase(files.previous)) {
    Logger.warning(
      'Restore: interrupted unverified swap found; rolling back to previous.',
    );
    await deleteDatabaseFileSet(database);
    await deleteDatabaseFileSet(files.staged);
    await moveDatabaseFileSet(files.previous, database);
    await deleteDatabaseFileSet(files.marker);
    return RestoreRecovery.rolledBack;
  }
  if (staged && isReadableDatabase(files.staged)) {
    Logger.warning('Restore: interrupted swap found; completing it.');
    await deleteDatabaseFileSet(database);
    await moveDatabaseFileSet(files.staged, database);
    await deleteDatabaseFileSet(files.previous);
    await deleteDatabaseFileSet(files.marker);
    return RestoreRecovery.completedRestore;
  }
  if (previous && isReadableDatabase(files.previous)) {
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

/// Checks that a database swapped in during a restore has a supported schema
/// version and a readable `accounts` table before deleting `.previous`.
bool _isVerifiedRestoredDatabase(File file) {
  sqlite.Database? db;
  try {
    db = sqlite.sqlite3.open(file.path);
    final version = db.select('PRAGMA user_version').first.values.first as int;
    if (version < AppDatabase.minimumSchemaVersion ||
        version > AppDatabase.currentSchemaVersion) {
      return false;
    }
    db.select('SELECT count(*) FROM accounts');
    return true;
  } on sqlite.SqliteException {
    return false;
  } finally {
    db?.close();
  }
}

/// Whether [file] is an SQLite database whose schema can be read.
bool isReadableDatabase(File file) {
  if (!file.existsSync()) {
    return false;
  }
  sqlite.Database? db;
  try {
    db = sqlite.sqlite3.open(file.path);
    db.select('SELECT count(*) FROM sqlite_master');
    return true;
  } on sqlite.SqliteException {
    return false;
  } finally {
    db?.close();
  }
}

/// What start-up found in the database file ([checkDatabaseFile]).
enum DatabaseFileState {
  /// No database yet: it is created on first use.
  missing,

  /// A database this version opens.
  usable,

  /// Not a readable SQLite database.
  damaged,

  /// A database of an early test version, older than
  /// [AppDatabase.minimumSchemaVersion] (not upgraded any more).
  tooOld,

  /// A database written by a newer version of LedgerZero.
  tooNew,
}

/// Checks [file] before the session opens it, after finishing an
/// interrupted restore. Throws only when the file cannot be read at all
/// (I/O), which may pass. Small synchronous reads, like the open itself.
Future<DatabaseFileState> checkDatabaseFile(File file) async {
  final restore = RestoreFiles(file);
  if ([
    restore.marker,
    restore.staged,
    restore.previous,
  ].any((f) => f.existsSync())) {
    await recoverInterruptedRestore(file);
  }
  if (!file.existsSync()) {
    return DatabaseFileState.missing;
  }
  sqlite.Database? db;
  try {
    final int version;
    try {
      db = sqlite.sqlite3.open(file.path);
      db.select('SELECT count(*) FROM sqlite_master');
      version = db.select('PRAGMA user_version').first.values.first as int;
    } on sqlite.SqliteException catch (e) {
      // Transient I/O, permission or busy errors (PERM=3, BUSY=5, LOCKED=6,
      // NOMEM=7, IOERR=10, FULL=13, CANTOPEN=14) may pass on retry, so
      // propagate them instead of offering a factory reset immediately.
      const transientCodes = {3, 5, 6, 7, 10, 13, 14};
      if (transientCodes.contains(e.resultCode)) {
        rethrow;
      }
      Logger.error('The database file cannot be read (${e.resultCode})');
      return DatabaseFileState.damaged;
    }
    // 0: an empty file, set up on first use like a new one.
    if (version != 0 && version < AppDatabase.minimumSchemaVersion) {
      return DatabaseFileState.tooOld;
    }
    if (version > AppDatabase.currentSchemaVersion) {
      return DatabaseFileState.tooNew;
    }
    return DatabaseFileState.usable;
  } finally {
    db?.close();
  }
}

/// Opens the app database ([databaseFile], or [file]).
///
/// Before opening, an interrupted restore is finished
/// ([recoverInterruptedRestore]), so a fresh database is never created
/// while a previous or staged copy exists.
QueryExecutor openConnection({File? file}) {
  return LazyDatabase(() async {
    final target = file ?? await databaseFile();
    await recoverInterruptedRestore(target);
    return NativeDatabase(target);
  });
}
