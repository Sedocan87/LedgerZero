import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/sqlcipher.dart';
import 'package:ledger_zero/services/backup/backup_format.dart';
import 'package:ledger_zero/services/backup/sync_rebootstrap.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

export 'package:ledger_zero/services/backup/backup_format.dart'
    show
        BackupException,
        BackupAuthenticationException,
        BackupFormatException,
        BackupTooNewException;

/// Closes and reopens the app's database connection around a file swap.
abstract class DatabaseLifecycle {
  /// Closes the current connection (no-op if none is open).
  Future<void> close();

  /// Opens the database file again and returns the new connection.
  Future<AppDatabase> reopen();
}

/// Restores `.lzbk` backups (format v2, and v1 for old files).
///
/// Full restore:
/// 1. decrypt into a temporary plain file (app temp directory);
/// 2. validate it: `integrity_check`, required tables, schema version
///    between 1 and [AppDatabase.schemaVersion]; older schemas are migrated
///    by opening the file through [AppDatabase];
/// 3. empty `pending_sync_changes` (see [SyncRebootstrap]);
/// 4. build a new database encrypted with the current data key
///    (`ATTACH ... KEY` + `sqlcipher_export`) next to the live file and
///    check it opens with that key;
/// 5. close the connection, move the live file to `<db>.previous`, move the
///    new file into place, reopen through [DatabaseLifecycle] and run a
///    query; on failure the previous file is moved back and reopened, on
///    success it is deleted (only one previous copy ever exists);
/// 6. delete the temporary plain file (always), mark sync for re-bootstrap.
class RestoreService {
  final AppDatabase Function() _currentDb;
  final DatabaseLifecycle? _lifecycle;
  final Future<File> Function()? _databaseFile;
  final Uint8List Function()? _dataKey;
  final SyncRebootstrap? _rebootstrap;
  final Future<Directory> Function() _tempDirectory;

  RestoreService(
    this._currentDb, {
    this._lifecycle,
    this._databaseFile,
    this._dataKey,
    this._rebootstrap,
    Future<Directory> Function()? tempDirectory,
  }) : _tempDirectory = tempDirectory ?? getTemporaryDirectory;

  static const Set<String> requiredTables = {
    'accounts',
    'transactions',
    'categories',
    'category_groups',
    'budgets',
    'payees',
  };

  /// Replaces the whole database with the backup in [backupFile].
  Future<void> restoreBackup(
    File backupFile, {
    required String password,
  }) async {
    final lifecycle = _lifecycle;
    final databaseFile = _databaseFile;
    final dataKey = _dataKey;
    if (lifecycle == null || databaseFile == null || dataKey == null) {
      throw StateError('RestoreService is not configured for full restores');
    }
    final work = await _workDirectory('restore');
    final dbFile = await databaseFile();
    final staged = File('${dbFile.path}.restore-new');
    try {
      final plain = File(p.join(work.path, 'restored.sqlite'));
      await BackupFormat.decryptFile(
        input: backupFile,
        output: plain,
        password: password,
      );
      await prepareRestoredDatabase(plain);
      await _deleteDatabaseFiles(staged);
      _buildEncryptedCopy(plain, staged, RawSqlCipherKey(dataKey()));
      await _swapIn(staged, dbFile, lifecycle);
      await _rebootstrap?.markRequired();
    } catch (e) {
      Logger.error('Restore failed', e.runtimeType);
      rethrow;
    } finally {
      await _deleteDatabaseFiles(staged);
      await _deleteDirectory(work);
    }
  }

  /// Validates the decrypted plain database [plain], migrates an older
  /// schema and clears its sync queue. Returns the schema version.
  Future<int> prepareRestoredDatabase(File plain) async {
    var version = _validate(plain);
    if (version < _currentSchemaVersion) {
      final migrating = AppDatabase(NativeDatabase(plain));
      try {
        await migrating.customSelect('SELECT 1').get();
      } finally {
        await migrating.close();
      }
      version = _validate(plain);
      if (version != _currentSchemaVersion) {
        throw const BackupFormatException('Backup could not be upgraded');
      }
    }
    final db = sqlite.sqlite3.open(plain.path);
    try {
      db.execute('DELETE FROM pending_sync_changes');
      db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    } on sqlite.SqliteException {
      // Table absent in very old schemas.
    } finally {
      db.close();
    }
    return version;
  }

  /// Merges transactions in [start]..[end] from a backup into the current
  /// database (missing accounts, categories, groups and payees are copied).
  Future<void> selectiveRestore(
    File backupFile,
    DateTime start,
    DateTime end, {
    required String password,
  }) async {
    final work = await _workDirectory('selective');
    try {
      final plain = File(p.join(work.path, 'selective.sqlite'));
      await BackupFormat.decryptFile(
        input: backupFile,
        output: plain,
        password: password,
      );
      await prepareRestoredDatabase(plain);
      final tempDb = AppDatabase(NativeDatabase(plain));
      final db = _currentDb();
      try {
        final transactionsToImport = await (tempDb.select(
          tempDb.transactions,
        )..where((t) => t.date.isBetweenValues(start, end))).get();

        Logger.info(
          'Found ${transactionsToImport.length} transactions to merge',
        );

        await db.transaction(() async {
          for (final tx in transactionsToImport) {
            final exists = await (db.select(
              db.transactions,
            )..where((t) => t.id.equals(tx.id))).getSingleOrNull();
            if (exists != null) {
              continue;
            }
            await _ensureDependenciesExist(db, tempDb, tx);
            await db.into(db.transactions).insert(tx);
          }
        });
      } finally {
        await tempDb.close();
      }
    } catch (e) {
      Logger.error('Selective restore failed', e.runtimeType);
      rethrow;
    } finally {
      await _deleteDirectory(work);
    }
  }

  int get _currentSchemaVersion => AppDatabase.currentSchemaVersion;

  int _validate(File plain) {
    final db = sqlite.sqlite3.open(plain.path);
    try {
      final List<sqlite.Row> integrity;
      try {
        integrity = db.select('PRAGMA integrity_check');
      } on sqlite.SqliteException {
        throw const BackupFormatException('Backup is not a database');
      }
      if (integrity.isEmpty || integrity.first.values.first != 'ok') {
        throw const BackupFormatException('Database integrity check failed');
      }
      final tables = db
          .select("SELECT name FROM sqlite_master WHERE type='table'")
          .map((row) => row['name'] as String)
          .toSet();
      if (!requiredTables.every(tables.contains)) {
        throw const BackupFormatException('Backup is missing required tables');
      }
      final version =
          db.select('PRAGMA user_version').first.values.first as int;
      if (version < 1) {
        throw const BackupFormatException('Backup has no schema version');
      }
      if (version > _currentSchemaVersion) {
        throw const BackupTooNewException();
      }
      return version;
    } finally {
      db.close();
    }
  }

  static void _buildEncryptedCopy(
    File plain,
    File target,
    RawSqlCipherKey key,
  ) {
    final db = sqlite.sqlite3.open(plain.path);
    try {
      SqlCipher.exportTo(db, target, key);
    } finally {
      db.close();
    }
    final check = sqlite.sqlite3.open(target.path);
    try {
      SqlCipher.applyKey(check, key);
      final integrity = check.select('PRAGMA integrity_check');
      if (integrity.isEmpty || integrity.first.values.first != 'ok') {
        throw const BackupException('Restored database failed its check');
      }
    } finally {
      check.close();
    }
  }

  static Future<void> _swapIn(
    File staged,
    File dbFile,
    DatabaseLifecycle lifecycle,
  ) async {
    final previous = File('${dbFile.path}.previous');
    await lifecycle.close();
    await _deleteDatabaseFiles(previous);
    await _moveDatabaseFiles(dbFile, previous);
    try {
      await staged.rename(dbFile.path);
      final reopened = await lifecycle.reopen();
      await reopened.customSelect('SELECT count(*) FROM accounts').get();
    } catch (e) {
      await lifecycle.close();
      await _deleteDatabaseFiles(dbFile);
      await _moveDatabaseFiles(previous, dbFile);
      await lifecycle.reopen();
      rethrow;
    }
    await _deleteDatabaseFiles(previous);
  }

  Future<Directory> _workDirectory(String name) async {
    final base = await _tempDirectory();
    final dir = Directory(
      p.join(base.path, '${name}_${DateTime.now().microsecondsSinceEpoch}'),
    );
    await dir.create(recursive: true);
    return dir;
  }

  static Future<void> _moveDatabaseFiles(File from, File to) async {
    for (final suffix in const ['', '-wal', '-shm']) {
      final f = File('${from.path}$suffix');
      if (await f.exists()) {
        await f.rename('${to.path}$suffix');
      }
    }
  }

  static Future<void> _deleteDatabaseFiles(File file) async {
    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      final f = File('${file.path}$suffix');
      try {
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
    }
  }

  static Future<void> _deleteDirectory(Directory dir) async {
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<void> _ensureDependenciesExist(
    AppDatabase db,
    AppDatabase tempDb,
    Transaction tx,
  ) async {
    final accountExists = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(tx.accountId))).getSingleOrNull();
    if (accountExists == null) {
      final account = await (tempDb.select(
        tempDb.accounts,
      )..where((a) => a.id.equals(tx.accountId))).getSingleOrNull();
      if (account != null) {
        await db.into(db.accounts).insert(account);
      }
    }

    if (tx.categoryId != null) {
      final catExists = await (db.select(
        db.categories,
      )..where((c) => c.id.equals(tx.categoryId!))).getSingleOrNull();
      if (catExists == null) {
        final cat = await (tempDb.select(
          tempDb.categories,
        )..where((c) => c.id.equals(tx.categoryId!))).getSingleOrNull();
        if (cat != null) {
          if (cat.categoryGroupId != null) {
            final groupExists =
                await (db.select(db.categoryGroups)
                      ..where((g) => g.id.equals(cat.categoryGroupId!)))
                    .getSingleOrNull();
            if (groupExists == null) {
              final group =
                  await (tempDb.select(tempDb.categoryGroups)
                        ..where((g) => g.id.equals(cat.categoryGroupId!)))
                      .getSingleOrNull();
              if (group != null) {
                await db.into(db.categoryGroups).insert(group);
              }
            }
          }
          await db.into(db.categories).insert(cat);
        }
      }
    }

    if (tx.payeeId != null) {
      final payeeExists = await (db.select(
        db.payees,
      )..where((p) => p.id.equals(tx.payeeId!))).getSingleOrNull();
      if (payeeExists == null) {
        final payee = await (tempDb.select(
          tempDb.payees,
        )..where((p) => p.id.equals(tx.payeeId!))).getSingleOrNull();
        if (payee != null) {
          await db.into(db.payees).insert(payee);
        }
      }
    }
  }
}
