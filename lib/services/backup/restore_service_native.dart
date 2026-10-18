import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/connection.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/sqlcipher.dart';
import 'package:ledger_zero/services/backup/backup_format.dart';
import 'package:ledger_zero/services/backup/sync_rebootstrap.dart';
import 'package:ledger_zero/services/sync/sync_local_state.dart';
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
///    (`ATTACH ... KEY` + `sqlcipher_export`, on a background isolate) next
///    to the live file and check it opens with that key;
/// 5. mark sync for re-bootstrap, write the restore marker
///    (`<db>.restoring`), close the connection, move the live file to
///    `<db>.previous`, move the new file into place, reopen through
///    [DatabaseLifecycle] and run a query; on failure the previous file is
///    moved back, reopened and the re-bootstrap flag cleared; on success
///    the previous file and the marker are deleted (only one previous copy
///    ever exists). If the process dies between the move and the rename,
///    the next open finishes the swap (`recoverInterruptedRestore`);
/// 6. delete the temporary plain file (always).
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
    final prepared = await prepareRestore(backupFile, password: password);
    await prepared.commit();
  }

  /// Decrypts and validates [backupFile] without touching the live
  /// database, so the caller can inspect [PreparedRestore.info] (member id,
  /// age) and warn the user before [PreparedRestore.commit] replaces the
  /// data. [PreparedRestore.discard] cleans up without restoring.
  Future<PreparedRestore> prepareRestore(
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
    try {
      final plain = File(p.join(work.path, 'restored.sqlite'));
      final backupInfo = await BackupFormat.decryptFile(
        input: backupFile,
        output: plain,
        password: password,
      );
      await prepareRestoredDatabase(plain);
      final info = await _inspect(plain, backupInfo);
      return PreparedRestore._(this, work, plain, info);
    } catch (e) {
      Logger.error('Restore failed', e.runtimeType);
      await _deleteDirectory(work);
      rethrow;
    }
  }

  /// What the user should know before the restore replaces the data.
  Future<RestoreInfo> _inspect(File plain, BackupInfo backupInfo) async {
    String? backupMember;
    var backupPersonal = 0;
    final db = sqlite.sqlite3.open(plain.path);
    try {
      backupMember =
          db
                  .select('SELECT value FROM sync_kv WHERE key = ?', [
                    AppDatabase.memberIdKey,
                  ])
                  .firstOrNull
                  ?.values
                  .first
              as String?;
      backupPersonal =
          db
                  .select(
                    'SELECT COUNT(*) FROM accounts WHERE owner_id IS NOT NULL',
                  )
                  .first
                  .values
                  .first
              as int;
    } finally {
      db.close();
    }
    final current = _currentDb();
    final localMember = await current.syncDao.getValue(AppDatabase.memberIdKey);
    final localPersonal =
        (await current
                .customSelect(
                  'SELECT COUNT(*) AS c FROM accounts WHERE owner_id IS NOT NULL',
                )
                .getSingle())
            .read<int>('c');
    return RestoreInfo(
      createdAt: backupInfo.createdAt,
      backupMemberId: backupMember,
      localMemberId: localMember,
      backupPersonalAccounts: backupPersonal,
      localPersonalAccounts: localPersonal,
    );
  }

  Future<void> _commit(Directory work, File plain) async {
    final lifecycle = _lifecycle!;
    final dbFile = await _databaseFile!();
    final staged = RestoreFiles(dbFile).staged;
    try {
      await deleteDatabaseFileSet(staged);
      final keyBytes = Uint8List.fromList(_dataKey!());
      await Isolate.run(() => _buildEncryptedCopy(plain, staged, keyBytes));
      // The flag goes first: sync is paused by the lifecycle, and a run that
      // starts after the reopen must already see it.
      await _rebootstrap?.markRequired();
      try {
        await _swapIn(staged, dbFile, lifecycle);
      } catch (_) {
        await _rebootstrap?.clear();
        rethrow;
      }
      await _rebootstrap?.discardOutbox();
    } catch (e) {
      Logger.error('Restore failed', e.runtimeType);
      rethrow;
    } finally {
      await deleteDatabaseFileSet(staged);
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
      // Never clone the backing phone's device id (see SyncDeviceId).
      db.execute('DELETE FROM sync_kv WHERE key = ?', [
        SyncLocalState.deviceIdKey,
      ]);
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

  /// Runs on a background isolate: `sqlcipher_export` of a whole database
  /// would otherwise block the UI long enough for an ANR.
  static void _buildEncryptedCopy(File plain, File target, Uint8List keyBytes) {
    final key = RawSqlCipherKey(keyBytes);
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
    final files = RestoreFiles(dbFile);
    final previous = files.previous;
    await lifecycle.close();
    await deleteDatabaseFileSet(previous);
    // From here until the marker is removed the live file may be missing;
    // `recoverInterruptedRestore` finishes the swap at the next open.
    await files.marker.writeAsString('1', flush: true);
    await moveDatabaseFileSet(dbFile, previous);
    try {
      await staged.rename(dbFile.path);
      final reopened = await lifecycle.reopen();
      await reopened.customSelect('SELECT count(*) FROM accounts').get();
    } catch (e) {
      await lifecycle.close();
      await deleteDatabaseFileSet(dbFile);
      await moveDatabaseFileSet(previous, dbFile);
      await deleteDatabaseFileSet(files.marker);
      await lifecycle.reopen();
      rethrow;
    }
    await deleteDatabaseFileSet(previous);
    await deleteDatabaseFileSet(files.marker);
  }

  Future<Directory> _workDirectory(String name) async {
    final base = await _tempDirectory();
    final dir = Directory(
      p.join(base.path, '${name}_${DateTime.now().microsecondsSinceEpoch}'),
    );
    await dir.create(recursive: true);
    return dir;
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

/// Facts about a backup and the current data that decide which warnings a
/// full restore needs (see docs/BACKUP_AND_EXPORT.md).
class RestoreInfo {
  const RestoreInfo({
    required this.createdAt,
    required this.backupMemberId,
    required this.localMemberId,
    required this.backupPersonalAccounts,
    required this.localPersonalAccounts,
  });

  /// When the backup was made (null for format v1 files).
  final DateTime? createdAt;

  /// The household member id stored in the backup (`sync_kv.member_id`).
  final String? backupMemberId;
  final String? localMemberId;
  final int backupPersonalAccounts;
  final int localPersonalAccounts;

  /// The restore changes who "I" am in the household: the backup carries
  /// another member id (or none) while this phone already has one or shows
  /// personal accounts. Afterwards the accounts personal to the backup's
  /// member are "mine" and today's own accounts become the partner's, with
  /// their transactions gone.
  bool get changesMember =>
      backupMemberId != localMemberId &&
      (localMemberId != null || localPersonalAccounts > 0);

  /// The backup is older than the sync tombstone retention: rows deleted
  /// elsewhere since may not be deleted again by sync.
  bool isOlderThan(Duration retention, {DateTime? now}) {
    final created = createdAt;
    if (created == null) {
      return false;
    }
    return (now ?? DateTime.now()).toUtc().difference(created) > retention;
  }
}

/// A decrypted, validated backup waiting for [commit] or [discard].
class PreparedRestore {
  PreparedRestore._(this._service, this._work, this._plain, this.info);

  final RestoreService _service;
  final Directory _work;
  final File _plain;
  final RestoreInfo info;
  bool _done = false;

  /// Replaces the live database with the backup.
  Future<void> commit() async {
    if (_done) {
      throw StateError('restore already finished');
    }
    _done = true;
    await _service._commit(_work, _plain);
  }

  /// Deletes the decrypted copy without restoring.
  Future<void> discard() async {
    _done = true;
    await RestoreService._deleteDirectory(_work);
  }
}
