import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:ledger_zero/core/constants/deterministic_id.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/domain/repositories/reference_maintenance_repository.dart';

class ReferenceMaintenanceRepositoryImpl
    implements ReferenceMaintenanceRepository {
  ReferenceMaintenanceRepositoryImpl(this._db);

  final AppDatabase _db;

  Variable<DateTime> get _now => Variable.withDateTime(DateTime.now().toUtc());

  Variable<String> _idOrNull(String? id) => Variable<String>(id);

  @override
  Future<void> reassignCategoryReferences(String fromId, String? toId) async {
    final from = Variable.withString(fromId);
    final to = _idOrNull(toId);
    await _db.customUpdate(
      'UPDATE transactions SET category_id = ?, updated_at = ? '
      'WHERE category_id = ?',
      variables: [to, _now, from],
      updates: {_db.transactions},
    );
    await _db.customUpdate(
      'UPDATE payees SET auto_category_id = ?, updated_at = ? '
      'WHERE auto_category_id = ?',
      variables: [to, _now, from],
      updates: {_db.payees},
    );
    await _db.customUpdate(
      'UPDATE scheduled_transactions SET category_id = ?, updated_at = ? '
      'WHERE category_id = ?',
      variables: [to, _now, from],
      updates: {_db.scheduledTransactions},
    );
    await _db.customUpdate(
      'UPDATE parsing_history SET category_id = ? WHERE category_id = ?',
      variables: [to, from],
      updates: {_db.parsingHistory},
    );
    await _reassignTemplateCategory(fromId, toId);
  }

  Future<void> _reassignTemplateCategory(String fromId, String? toId) async {
    final templates = await _db.select(_db.budgetTemplates).get();
    for (final template in templates) {
      Map<String, dynamic> data;
      try {
        data = jsonDecode(template.data) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      if (!data.containsKey(fromId)) {
        continue;
      }
      final amount = (data.remove(fromId) as num?)?.toInt() ?? 0;
      if (toId != null) {
        data[toId] = ((data[toId] as num?)?.toInt() ?? 0) + amount;
      }
      await (_db.update(
        _db.budgetTemplates,
      )..where((t) => t.id.equals(template.id))).write(
        BudgetTemplatesCompanion(
          data: Value(jsonEncode(data)),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    }
  }

  @override
  Future<void> moveBudgets(String fromId, String? toId) async {
    final source = await (_db.select(
      _db.budgets,
    )..where((b) => b.categoryId.equals(fromId))).get();
    for (final row in source) {
      if (toId != null && row.budgeted != 0) {
        final target =
            await (_db.select(_db.budgets)..where(
                  (b) => b.categoryId.equals(toId) & b.month.equals(row.month),
                ))
                .getSingleOrNull();
        final now = DateTime.now().toUtc();
        if (target != null) {
          await (_db.update(
            _db.budgets,
          )..where((b) => b.id.equals(target.id))).write(
            BudgetsCompanion(
              budgeted: Value(target.budgeted + row.budgeted),
              updatedAt: Value(now),
            ),
          );
        } else {
          await _db
              .into(_db.budgets)
              .insert(
                BudgetsCompanion.insert(
                  id: DeterministicId.budgetForKey(toId, row.month),
                  categoryId: toId,
                  month: row.month,
                  budgeted: Value(row.budgeted),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
        }
      }
      await (_db.delete(_db.budgets)..where((b) => b.id.equals(row.id))).go();
    }
  }

  @override
  Future<void> moveCategoriesToGroup(
    String fromGroupId,
    String toGroupId,
  ) async {
    await _db.customUpdate(
      'UPDATE categories SET category_group_id = ?, updated_at = ? '
      'WHERE category_group_id = ?',
      variables: [
        Variable.withString(toGroupId),
        _now,
        Variable.withString(fromGroupId),
      ],
      updates: {_db.categories},
    );
  }

  @override
  Future<int> countTransactionsWithCategory(String categoryId) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM transactions '
          'WHERE category_id = ? AND is_deleted = 0',
          variables: [Variable.withString(categoryId)],
          readsFrom: {_db.transactions},
        )
        .getSingle();
    return row.read<int>('c');
  }

  @override
  Future<int> countCategoriesInGroup(String groupId) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM categories WHERE category_group_id = ?',
          variables: [Variable.withString(groupId)],
          readsFrom: {_db.categories},
        )
        .getSingle();
    return row.read<int>('c');
  }

  @override
  Future<int> detachTransfersInto(String accountId) async {
    final id = Variable.withString(accountId);
    final live = await _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM transactions WHERE transfer_account_id = ? '
          'AND account_id <> ? AND is_deleted = 0',
          variables: [id, id],
          readsFrom: {_db.transactions},
        )
        .getSingle();
    await _db.customUpdate(
      'UPDATE transactions SET transfer_account_id = NULL, '
      'transfer_transaction_id = NULL, updated_at = ? '
      'WHERE transfer_account_id = ? AND account_id <> ?',
      variables: [_now, id, id],
      updates: {_db.transactions},
    );
    return live.read<int>('c');
  }

  @override
  Future<void> deleteTransactionsOfAccount(String accountId) async {
    final id = Variable.withString(accountId);
    // Children first (they reference their parent).
    await _db.customUpdate(
      'DELETE FROM transactions WHERE parent_transaction_id IN '
      '(SELECT id FROM transactions WHERE account_id = ?)',
      variables: [id],
      updates: {_db.transactions},
      updateKind: UpdateKind.delete,
    );
    await _db.customUpdate(
      'DELETE FROM transactions WHERE account_id = ?',
      variables: [id],
      updates: {_db.transactions},
      updateKind: UpdateKind.delete,
    );
  }

  @override
  Future<void> deleteScheduledTransactionsOfAccount(String accountId) async {
    await _db.customUpdate(
      'DELETE FROM scheduled_transactions WHERE account_id = ?',
      variables: [Variable.withString(accountId)],
      updates: {_db.scheduledTransactions},
      updateKind: UpdateKind.delete,
    );
  }

  @override
  Future<void> clearPayeeDefaultAccount(String accountId) async {
    await _db.customUpdate(
      'UPDATE payees SET default_account_id = NULL, updated_at = ? '
      'WHERE default_account_id = ?',
      variables: [_now, Variable.withString(accountId)],
      updates: {_db.payees},
    );
  }

  @override
  Future<void> reassignPayeeReferences(String fromId, String? toId) async {
    final from = Variable.withString(fromId);
    final to = _idOrNull(toId);
    await _db.customUpdate(
      'UPDATE transactions SET payee_id = ?, updated_at = ? WHERE payee_id = ?',
      variables: [to, _now, from],
      updates: {_db.transactions},
    );
    await _db.customUpdate(
      'UPDATE scheduled_transactions SET payee_id = ?, updated_at = ? '
      'WHERE payee_id = ?',
      variables: [to, _now, from],
      updates: {_db.scheduledTransactions},
    );
    await _db.customUpdate(
      'UPDATE parsing_history SET payee_id = ? WHERE payee_id = ?',
      variables: [to, from],
      updates: {_db.parsingHistory},
    );
  }
}
