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
  /// database, as new local edits.
  ///
  /// * Row families travel together: a split parent with all its children,
  ///   both legs of a transfer (parents are inserted first). A transfer leg
  ///   whose other account or other leg is not available becomes a normal
  ///   uncategorised row.
  /// * Missing accounts (transfer accounts included), categories, groups
  ///   and payees are copied from the backup.
  /// * Rows of the partner's personal accounts are left out, and nothing
  ///   is copied into them.
  /// * Every inserted row gets `updated_at` = now, so sync treats it as a
  ///   fresh edit (an older timestamp would lose against the partner's
  ///   newer version or tombstone and leave the phones diverged).
  /// Rows whose id already exists are left untouched.
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
        final inRange = await (tempDb.select(
          tempDb.transactions,
        )..where((t) => t.date.isBetweenValues(start, end))).get();
        final family = await _collectFamilies(tempDb, inRange);
        Logger.info(
          'Found ${inRange.length} transactions to merge '
          '(${family.length} with their families)',
        );
        final merge = _SelectiveMerge(
          db,
          tempDb,
          localMemberId: await db.syncDao.getValue(AppDatabase.memberIdKey),
          now: DateTime.now().toUtc(),
        );
        await db.transaction(() async {
          await db.customStatement('PRAGMA defer_foreign_keys = ON');
          for (final tx in merge.parentsFirst(family.values)) {
            await merge.insertTransaction(tx, family);
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

  /// [seeds] plus everything that must travel with them: split parents and
  /// children, the other leg of a transfer.
  static Future<Map<String, Transaction>> _collectFamilies(
    AppDatabase tempDb,
    List<Transaction> seeds,
  ) async {
    final result = <String, Transaction>{};
    final queue = [...seeds];
    Future<Transaction?> fetch(String id) => (tempDb.select(
      tempDb.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    while (queue.isNotEmpty) {
      final tx = queue.removeLast();
      if (result.containsKey(tx.id)) {
        continue;
      }
      result[tx.id] = tx;
      final parent = tx.parentTransactionId;
      if (parent != null && !result.containsKey(parent)) {
        final row = await fetch(parent);
        if (row != null) {
          queue.add(row);
        }
      }
      queue.addAll(
        await (tempDb.select(
          tempDb.transactions,
        )..where((t) => t.parentTransactionId.equals(tx.id))).get(),
      );
      final leg = tx.transferTransactionId;
      if (leg != null && !result.containsKey(leg)) {
        final row = await fetch(leg);
        if (row != null) {
          queue.add(row);
        }
      }
    }
    return result;
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

/// One selective restore: copies rows from [tempDb] (the backup) into [db].
class _SelectiveMerge {
  _SelectiveMerge(
    this.db,
    this.tempDb, {
    required this.localMemberId,
    required this.now,
  });

  final AppDatabase db;
  final AppDatabase tempDb;
  final String? localMemberId;
  final DateTime now;

  /// Ids of transactions that were inserted or already exist locally.
  final Set<String> _available = {};

  /// Ids that were left out (partner's account, or a parent left out).
  final Set<String> _skipped = {};

  /// Accounts already checked: id -> usable here (exists or was copied).
  final Map<String, bool> _accounts = {};

  Iterable<Transaction> parentsFirst(Iterable<Transaction> rows) =>
      rows.toList()..sort(
        (a, b) => (a.parentTransactionId == null ? 0 : 1).compareTo(
          b.parentTransactionId == null ? 0 : 1,
        ),
      );

  Future<void> insertTransaction(
    Transaction tx,
    Map<String, Transaction> family,
  ) async {
    if (await _exists(db.transactions, tx.id)) {
      _available.add(tx.id);
      return;
    }
    final parent = tx.parentTransactionId;
    if (parent != null && !_available.contains(parent)) {
      _skipped.add(tx.id); // its parent was left out
      return;
    }
    if (!await _ensureAccount(tx.accountId)) {
      _skipped.add(tx.id); // the partner's account, or unknown
      return;
    }
    var row = tx;
    final transferAccount = row.transferAccountId;
    final leg = row.transferTransactionId;
    if (transferAccount != null || leg != null) {
      final otherAccountOk =
          transferAccount != null && await _ensureAccount(transferAccount);
      final otherLegOk =
          leg != null &&
          (_available.contains(leg) ||
              (family.containsKey(leg) && !_skipped.contains(leg)) ||
              await _exists(db.transactions, leg));
      if (!otherAccountOk || !otherLegOk) {
        // Half a transfer is a normal, uncategorised row.
        row = row.copyWith(
          transferAccountId: const Value(null),
          transferTransactionId: const Value(null),
        );
      }
    }
    if (row.categoryId != null && !await _ensureCategory(row.categoryId!)) {
      row = row.copyWith(categoryId: const Value(null));
    }
    if (row.payeeId != null && !await _ensurePayee(row.payeeId!)) {
      row = row.copyWith(payeeId: const Value(null));
    }
    await db
        .into(db.transactions)
        .insert(
          row.copyWith(
            createdAt: Value(row.createdAt ?? now),
            updatedAt: Value(now),
          ),
        );
    _available.add(tx.id);
  }

  Future<bool> _exists(TableInfo<Table, dynamic> table, String id) async {
    final row = await db
        .customSelect(
          'SELECT 1 FROM "${table.actualTableName}" WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    return row != null;
  }

  /// Whether rows may be written into account [id] here. The partner's
  /// personal accounts (owner set, not this member) are never touched.
  Future<bool> _ensureAccount(String id) async {
    final cached = _accounts[id];
    if (cached != null) {
      return cached;
    }
    final local = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (local != null) {
      return _accounts[id] = !_partners(local.ownerId);
    }
    final backup = await (tempDb.select(
      tempDb.accounts,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (backup == null || _partners(backup.ownerId)) {
      return _accounts[id] = false;
    }
    await db.into(db.accounts).insert(backup.copyWith(updatedAt: Value(now)));
    return _accounts[id] = true;
  }

  bool _partners(String? ownerId) =>
      ownerId != null && ownerId != localMemberId;

  /// Whether category [id] is available here (existed or was copied).
  Future<bool> _ensureCategory(String id) async {
    if (await _exists(db.categories, id)) {
      return true;
    }
    final cat = await (tempDb.select(
      tempDb.categories,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    if (cat == null) {
      return false;
    }
    final group = cat.categoryGroupId;
    if (group != null && !await _exists(db.categoryGroups, group)) {
      final row = await (tempDb.select(
        tempDb.categoryGroups,
      )..where((g) => g.id.equals(group))).getSingleOrNull();
      if (row != null) {
        await db
            .into(db.categoryGroups)
            .insert(row.copyWith(updatedAt: Value(now)));
      }
    }
    await db.into(db.categories).insert(cat.copyWith(updatedAt: Value(now)));
    return true;
  }

  Future<bool> _ensurePayee(String id) async {
    if (await _exists(db.payees, id)) {
      return true;
    }
    final payee = await (tempDb.select(
      tempDb.payees,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
    if (payee == null) {
      return false;
    }
    await db.into(db.payees).insert(payee.copyWith(updatedAt: Value(now)));
    return true;
  }
}
