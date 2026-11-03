// "Keep mine" on a conflict whose local version was a delete: the row is
// deleted again the way the app deletes it, with its cascades, instead of
// a raw DELETE that fails on rows referencing it.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/domain/entities/budget.dart' as domain;
import 'package:ledger_zero/domain/entities/payee.dart' as domain;
import 'package:ledger_zero/services/sync/sync_conflict_resolver.dart';
import 'package:ledger_zero/services/sync/sync_schema.dart';

import '../../domain/services/ledger_test_helpers.dart';
import '../../helpers/test_database.dart';

void main() {
  late TestDatabase t;
  late SyncConflictResolver resolver;
  final day = DateTime.utc(2026, 10, 5);
  final now = DateTime.utc(2026, 10, 20, 12);

  setUp(() async {
    t = TestDatabase();
    resolver = SyncConflictResolver(t.db);
    await t.addAccount(id: 'checking', name: 'Checking');
    await t.addAccount(id: 'savings', name: 'Savings');
  });

  tearDown(() => t.close());

  /// Records that the remote version of [table] row [id] replaced a local
  /// delete.
  Future<int> deleteConflict(String table, String id) =>
      t.db.syncDao.addConflict(
        SyncConflictsCompanion.insert(
          syncTable: table,
          rowId: id,
          localSnapshot: const Value(null),
          remoteSnapshot: const Value('{}'),
          remoteDeviceId: 'device-b',
          resolvedAt: now,
        ),
      );

  Future<Map<String, Object?>?> raw(String table, String id) async =>
      (await t.db
              .customSelect(
                'SELECT * FROM "$table" WHERE id = ?',
                variables: [Variable.withString(id)],
              )
              .getSingleOrNull())
          ?.data;

  Future<List<String>> pendingDeletes(String table) async {
    final rows = await t.db
        .customSelect(
          "SELECT record_id FROM pending_sync_changes WHERE action = 'DELETE' "
          'AND table_name = ?',
          variables: [Variable.withString(table)],
        )
        .get();
    return [for (final r in rows) r.read<String>('record_id')];
  }

  test('a split transaction is deleted with all its lines', () async {
    final groceries = await t.categoryId('Groceries');
    await t.addTransaction(
      id: 'parent',
      accountId: 'checking',
      amount: -300,
      date: day,
    );
    for (final line in ['a', 'b']) {
      await t.addTransaction(
        id: 'line-$line',
        accountId: 'checking',
        amount: -150,
        date: day,
        categoryId: groceries,
        parentTransactionId: 'parent',
      );
    }
    // The remote version is stamped ahead of this phone's clock.
    final remoteStamp = now.add(const Duration(hours: 2));
    await t.db.customStatement(
      "UPDATE transactions SET updated_at = ? WHERE id = 'parent'",
      [remoteStamp.toIso8601String()],
    );
    final id = await deleteConflict('transactions', 'parent');

    await resolver.keepMine(id, now: now);

    for (final rowId in ['parent', 'line-a', 'line-b']) {
      final row = (await raw('transactions', rowId))!;
      expect(row['is_deleted'], 1, reason: rowId);
    }
    final parent = (await raw('transactions', 'parent'))!;
    expect(
      SyncSchema.versionOf(parent['updated_at']),
      greaterThan(remoteStamp.microsecondsSinceEpoch),
    );
    expect(await t.db.syncDao.getConflicts(), isEmpty);
    expect(await t.accounts.getAccountById('checking'), isNotNull);
    await expectNoForeignKeyViolations(t);
  });

  test('a split line takes its whole split; a transfer leg takes the other '
      'leg', () async {
    await t.addTransaction(
      id: 'parent',
      accountId: 'checking',
      amount: -300,
      date: day,
    );
    for (final line in ['a', 'b']) {
      await t.addTransaction(
        id: 'line-$line',
        accountId: 'checking',
        amount: -150,
        date: day,
        parentTransactionId: 'parent',
      );
    }
    await t.addTransaction(
      id: 'out',
      accountId: 'checking',
      amount: -500,
      date: day,
      transferAccountId: 'savings',
      transferTransactionId: 'in',
    );
    await t.addTransaction(
      id: 'in',
      accountId: 'savings',
      amount: 500,
      date: day,
      transferAccountId: 'checking',
      transferTransactionId: 'out',
    );

    await resolver.keepMine(await deleteConflict('transactions', 'line-a'));
    await resolver.keepMine(await deleteConflict('transactions', 'in'));

    for (final rowId in ['parent', 'line-a', 'line-b', 'out', 'in']) {
      expect((await raw('transactions', rowId))!['is_deleted'], 1);
    }
  });

  test('a category with budgets and transactions is deleted; its '
      'transactions become uncategorised', () async {
    final groceries = await t.categoryId('Groceries');
    await t.budgets.createBudget(
      domain.Budget(
        id: 'budget-1',
        categoryId: groceries,
        month: '2026-10',
        budgeted: 20000,
      ),
    );
    await t.addTransaction(
      id: 'shopping',
      accountId: 'checking',
      amount: -1250,
      date: day,
      categoryId: groceries,
    );
    final id = await deleteConflict('categories', groceries);

    await resolver.keepMine(id, now: now);

    expect(await raw('categories', groceries), isNull);
    expect(await raw('budgets', 'budget-1'), isNull);
    final shopping = (await raw('transactions', 'shopping'))!;
    expect(shopping['category_id'], isNull);
    expect(shopping['is_deleted'], 0);
    expect(await pendingDeletes('categories'), contains(groceries));
    expect(await t.db.syncDao.getConflicts(), isEmpty);
    await expectNoForeignKeyViolations(t);
  });

  test('a payee with transactions is deleted; the references are '
      'cleared', () async {
    await t.payees.createPayee(const domain.Payee(id: 'rewe', name: 'REWE'));
    await t.addTransaction(
      id: 'shopping',
      accountId: 'checking',
      amount: -1250,
      date: day,
      payeeId: 'rewe',
    );

    await resolver.keepMine(await deleteConflict('payees', 'rewe'));

    expect(await raw('payees', 'rewe'), isNull);
    expect((await raw('transactions', 'shopping'))!['payee_id'], isNull);
    await expectNoForeignKeyViolations(t);
  });

  test('an account is deleted with its transactions; transfer legs '
      'elsewhere stay as normal transactions', () async {
    await t.addTransaction(
      id: 'own',
      accountId: 'savings',
      amount: -100,
      date: day,
    );
    await t.addTransaction(
      id: 'out',
      accountId: 'checking',
      amount: -500,
      date: day,
      transferAccountId: 'savings',
      transferTransactionId: 'in',
    );
    await t.addTransaction(
      id: 'in',
      accountId: 'savings',
      amount: 500,
      date: day,
      transferAccountId: 'checking',
      transferTransactionId: 'out',
    );

    await resolver.keepMine(await deleteConflict('accounts', 'savings'));

    expect(await raw('accounts', 'savings'), isNull);
    expect(await raw('transactions', 'own'), isNull);
    expect(await raw('transactions', 'in'), isNull);
    final out = (await raw('transactions', 'out'))!;
    expect(out['transfer_account_id'], isNull);
    expect(out['transfer_transaction_id'], isNull);
    await expectNoForeignKeyViolations(t);
  });

  test('a category group moves its categories to another group', () async {
    final groups = await t.categories.getAllCategoryGroups();
    final group = groups.first;
    final inGroup = [
      for (final c in await t.categories.getAllCategories())
        if (c.categoryGroupId == group.id) c.id,
    ];
    expect(inGroup, isNotEmpty);

    await resolver.keepMine(await deleteConflict('category_groups', group.id));

    expect(await raw('category_groups', group.id), isNull);
    for (final id in inGroup) {
      final category = (await raw('categories', id))!;
      expect(category['category_group_id'], isNot(group.id));
      expect(category['category_group_id'], isNotNull);
    }
    await expectNoForeignKeyViolations(t);
  });
}
