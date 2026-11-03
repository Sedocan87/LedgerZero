import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/drift_unit_of_work.dart';
import 'package:ledger_zero/data/repositories/account_repository_impl.dart';
import 'package:ledger_zero/data/repositories/category_repository_impl.dart';
import 'package:ledger_zero/data/repositories/payee_repository_impl.dart';
import 'package:ledger_zero/data/repositories/reference_maintenance_repository_impl.dart';
import 'package:ledger_zero/data/repositories/rule_repository_impl.dart';
import 'package:ledger_zero/domain/services/account_service.dart';
import 'package:ledger_zero/domain/services/category_service.dart';
import 'package:ledger_zero/domain/services/payee_service.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';
import 'package:ledger_zero/services/sync/sync_schema.dart';

/// The user's choices for a recorded sync conflict.
class SyncConflictResolver {
  final AppDatabase _db;
  late final SyncSchema _schema = SyncSchema.of(_db);

  /// Cleared when keeping a delete removes an account, category or payee
  /// (as the domain services do): recorded snapshots may reference it.
  final UndoService? _undoService;

  SyncConflictResolver(this._db, {UndoService? undoService})
    : // A named parameter cannot be a private initializing formal.
      // ignore: prefer_initializing_formals
      _undoService = undoService;

  /// Removes the conflict from the list; the remote version stays.
  Future<void> dismiss(int conflictId) =>
      _db.syncDao.deleteConflict(conflictId);

  /// Re-applies the local snapshot as a new local edit (current time as
  /// `updated_at`), which then syncs to the other devices and wins there.
  ///
  /// If the local version was a delete, the row is deleted again the way
  /// the app deletes it (see [_deleteAgain]), so rows that reference it
  /// (split lines, budgets, transactions of a category, ...) are handled
  /// like a delete in the UI instead of failing on a foreign key.
  ///
  /// Throws if the snapshot can no longer be written (e.g. it references a
  /// row that was deleted since); nothing is changed then.
  Future<void> keepMine(int conflictId, {DateTime? now}) async {
    final conflict = await _db.syncDao.getConflict(conflictId);
    if (conflict == null) {
      return;
    }
    final table = _schema[conflict.syncTable];
    if (table == null) {
      await _db.syncDao.deleteConflict(conflictId);
      return;
    }
    await _db.transaction(() async {
      final snapshot = conflict.localSnapshot;
      if (snapshot == null) {
        await _deleteAgain(table.name, conflict.rowId, now: now);
      } else {
        final row = Map<String, Object?>.from(
          jsonDecode(snapshot) as Map<String, dynamic>,
        );
        row.removeWhere((column, _) => !table.hasColumn(column));
        if (table.hasColumn('updated_at')) {
          row['updated_at'] = await _winningStamp(
            table.name,
            conflict.rowId,
            now: now,
          );
        }
        // The remote winner may hold the same natural key under another id.
        for (final key in table.naturalKeys) {
          final values = [for (final c in key) row[c]];
          if (values.any((v) => v == null)) {
            continue;
          }
          await _db.customStatement(
            'DELETE FROM "${table.name}" WHERE '
            '${key.map((c) => '"$c" = ?').join(' AND ')} AND id != ?',
            [...values, conflict.rowId],
          );
        }
        final columns = row.keys.toList();
        await _db.customStatement(
          'INSERT INTO "${table.name}" '
          '(${columns.map((c) => '"$c"').join(', ')}) '
          'VALUES (${List.filled(columns.length, '?').join(', ')}) '
          'ON CONFLICT(id) DO UPDATE SET '
          '${columns.where((c) => c != 'id').map((c) => '"$c" = excluded."$c"').join(', ')}',
          [for (final c in columns) row[c]],
        );
      }
      await _db.syncDao.deleteConflict(conflictId);
    });
    // Raw statements do not notify drift's streams; a delete may also have
    // touched the tables that referenced the row.
    _db.notifyUpdates({
      for (final t in _db.allTables)
        if (AppDatabase.syncedTables.contains(t.actualTableName))
          TableUpdate.onTable(t),
    });
  }

  /// An ISO-8601 `updated_at` newer than every version of [table] row [id]
  /// seen here (its current `updated_at` and the last synced version), so
  /// the write wins on every device even with a clock behind theirs.
  Future<String> _winningStamp(String table, String id, {DateTime? now}) async {
    final current = await _db
        .customSelect(
          'SELECT updated_at FROM "$table" WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    final known = await _db.syncDao.getVersion(table, id);
    var micros = (now ?? DateTime.now()).toUtc().microsecondsSinceEpoch;
    for (final v in [
      SyncSchema.versionOf(current?.data['updated_at']),
      known?.version ?? 0,
    ]) {
      if (v >= micros) {
        micros = v + 1000;
      }
    }
    return DateTime.fromMicrosecondsSinceEpoch(
      micros,
      isUtc: true,
    ).toIso8601String();
  }

  /// Deletes [table] row [id] again (the local version of a conflict was a
  /// delete) with the same cascades as a delete in the app:
  ///
  /// * transactions: the whole group is deleted like
  ///   `TransactionService.deleteMany` does (soft delete of the row, its
  ///   split parent and lines, and its transfer counterpart), stamped to
  ///   win over the remote versions;
  /// * accounts: `AccountService.deleteAccount` (transfer legs elsewhere
  ///   become normal transactions, the account's transactions and
  ///   schedules are deleted, payee defaults and rule actions cleared);
  /// * categories: `CategoryService.deleteCategory` without a target (its
  ///   budgets are deleted, its transactions become uncategorised, other
  ///   references are cleared). Which category the original delete moved
  ///   things to is not known any more;
  /// * category groups: `CategoryService.deleteCategoryGroup`; categories
  ///   that are in it now move to the first other group;
  /// * payees: `PayeeService.deletePayee` (references cleared);
  /// * everything else has no rows referencing it and is deleted directly.
  ///
  /// Hard deletes always win over the version they delete (a tombstone is
  /// never older than the row it removes).
  Future<void> _deleteAgain(String table, String id, {DateTime? now}) async {
    final maintenance = ReferenceMaintenanceRepositoryImpl(_db);
    final rules = RuleRepositoryImpl(_db.rulesDao);
    final unitOfWork = DriftUnitOfWork(_db);
    switch (table) {
      case 'transactions':
        await _deleteTransactionGroup(id, now: now);
      case 'accounts':
        await AccountService(
          accountRepository: AccountRepositoryImpl(_db.accountsDao),
          maintenance: maintenance,
          ruleRepository: rules,
          unitOfWork: unitOfWork,
          undoService: _undoService,
        ).deleteAccount(id);
      case 'categories':
        await _categoryService(
          maintenance,
          rules,
          unitOfWork,
        ).deleteCategory(id, reassignTo: null);
      case 'category_groups':
        final categories = CategoryRepositoryImpl(_db.categoriesDao);
        final others = [
          for (final g in await categories.getAllCategoryGroups())
            if (g.id != id) g,
        ]..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
        await _categoryService(
          maintenance,
          rules,
          unitOfWork,
        ).deleteCategoryGroup(id, moveCategoriesTo: others.firstOrNull?.id);
      case 'payees':
        await PayeeService(
          payeeRepository: PayeeRepositoryImpl(_db.payeesDao),
          maintenance: maintenance,
          ruleRepository: rules,
          unitOfWork: unitOfWork,
          undoService: _undoService,
        ).deletePayee(id);
      default:
        await _db.customStatement('DELETE FROM "$table" WHERE id = ?', [id]);
    }
  }

  CategoryService _categoryService(
    ReferenceMaintenanceRepositoryImpl maintenance,
    RuleRepositoryImpl rules,
    DriftUnitOfWork unitOfWork,
  ) => CategoryService(
    categoryRepository: CategoryRepositoryImpl(_db.categoriesDao),
    maintenance: maintenance,
    ruleRepository: rules,
    unitOfWork: unitOfWork,
    undoService: _undoService,
  );

  /// Soft-deletes transaction [id] with everything that belongs to it, as
  /// `TransactionService` deletes a transaction: its split parent and all
  /// lines of the split (a split without some of its lines would not add
  /// up) and its transfer counterpart.
  Future<void> _deleteTransactionGroup(String id, {DateTime? now}) async {
    final dao = _db.transactionsDao;
    final row = await dao.getTransactionById(id);
    if (row == null) {
      return;
    }
    final root = row.parentTransactionId == null
        ? row
        : await dao.getTransactionById(row.parentTransactionId!) ?? row;
    final ids = <String>{root.id, row.id};
    if (root.transferTransactionId != null) {
      ids.add(root.transferTransactionId!);
    }
    for (final child in await dao.getSplitTransactions(root.id)) {
      ids.add(child.id);
    }
    for (final groupId in ids) {
      await _db.customStatement(
        'UPDATE transactions SET is_deleted = 1, updated_at = ? '
        'WHERE id = ? AND is_deleted = 0',
        [await _winningStamp('transactions', groupId, now: now), groupId],
      );
    }
  }
}
