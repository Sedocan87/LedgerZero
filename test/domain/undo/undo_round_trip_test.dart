// Undo/redo round trips on a real database for every recorded action type:
// after undo the visible ledger (live rows, balances, budgets, TBB) is
// exactly what it was before the action; after redo exactly what it was
// after it. The budget invariant holds at every step.
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';
import 'package:ledger_zero/domain/undo/budget_undo_actions.dart';

import '../../helpers/test_database.dart';
import '../services/ledger_test_helpers.dart';

void main() {
  late TestDatabase t;
  late UndoService undo;
  late TransactionService service;
  late String checking;
  late String savings;
  late String groceries;
  late String dining;
  final month = DateTime.utc(2024, 3);
  final day = DateTime.utc(2024, 3, 15);

  setUp(() async {
    t = TestDatabase();
    undo = UndoService();
    service = TransactionService(
      transactionRepository: t.transactions,
      payeeRepository: t.payees,
      undoService: undo,
      unitOfWork: t.unitOfWork,
    );
    checking = (await t.addAccount(
      name: 'Checking',
      startingBalance: 100000,
    )).id;
    savings = (await t.addAccount(name: 'Savings')).id;
    groceries = await t.categoryId('Groceries');
    dining = await t.categoryId('Dining Out');
    await t.budgeting.setCategoryBudgetedAmount(groceries, 30000, month);
  });

  tearDown(() => t.close());

  /// Everything a user can see of the ledger, without bookkeeping columns
  /// (updated_at, soft-deleted rows).
  Future<Map<String, Object?>> snapshot() async {
    final rows = await t.transactions.getAllTransactions();
    final live = {
      for (final r in rows)
        r.id: [
          r.accountId,
          r.date.toIso8601String(),
          r.amount,
          r.categoryId,
          r.payeeId,
          r.memo,
          r.cleared.name,
          r.approved,
          r.transferAccountId,
          r.transferTransactionId,
          r.parentTransactionId,
        ],
    };
    final accounts = await t.accounts.getAllAccounts();
    final budgets = await t.db.select(t.db.budgets).get();
    return {
      'rows': live,
      'balances': {for (final a in accounts) a.id: a.balance},
      // A budget row of 0 is the same as no row.
      'budgets': {
        for (final b in budgets)
          if (b.budgeted != 0) '${b.categoryId}/${b.month}': b.budgeted,
      },
      'tbb': await t.budgeting.calculateTBB(month),
      'groceries': await t.budgeting.calculateCategoryAvailable(
        groceries,
        month,
      ),
      'dining': await t.budgeting.calculateCategoryAvailable(dining, month),
    };
  }

  /// Runs [action], then checks undo -> before, redo -> after, undo again.
  Future<void> roundTrip(Future<void> Function() action) async {
    final before = await snapshot();
    await action();
    final after = await snapshot();
    expect(after, isNot(equals(before)), reason: 'the action changed nothing');
    await expectLedgerInvariant(t, month);

    await undo.undo();
    expect(await snapshot(), before, reason: 'undo');
    await expectLedgerInvariant(t, month);

    await undo.redo();
    expect(await snapshot(), after, reason: 'redo');
    await expectLedgerInvariant(t, month);

    await undo.undo();
    expect(await snapshot(), before, reason: 'second undo');
    await expectNoForeignKeyViolations(t);
  }

  Future<String> save(TransactionInput input) async =>
      (await service.save(input)).id;

  TransactionInput spend(int amount, {String? categoryId, String? id}) =>
      TransactionInput(
        id: id,
        accountId: checking,
        date: day,
        amount: amount,
        categoryId: categoryId ?? groceries,
      );

  test('create a normal transaction', () async {
    await roundTrip(() => save(spend(-1500)));
  });

  test('create a transfer (both legs)', () async {
    await roundTrip(
      () => save(
        TransactionInput(
          accountId: checking,
          date: day,
          amount: -20000,
          transferAccountId: savings,
        ),
      ),
    );
  });

  test('create a split', () async {
    await roundTrip(
      () => save(
        TransactionInput(
          accountId: checking,
          date: day,
          amount: -5000,
          splits: [
            SplitLineInput(amount: -3000, categoryId: groceries),
            SplitLineInput(amount: -2000, categoryId: dining),
          ],
        ),
      ),
    );
  });

  test('edit amount and category', () async {
    final id = await save(spend(-1500));
    await roundTrip(() => save(spend(-2500, categoryId: dining, id: id)));
  });

  test('convert a normal transaction into a transfer', () async {
    final id = await save(spend(-1500));
    await roundTrip(
      () => save(
        TransactionInput(
          id: id,
          accountId: checking,
          date: day,
          amount: -1500,
          transferAccountId: savings,
        ),
      ),
    );
  });

  test('delete a transfer (both legs)', () async {
    final id = await save(
      TransactionInput(
        accountId: checking,
        date: day,
        amount: -20000,
        transferAccountId: savings,
      ),
    );
    await roundTrip(() => service.deleteTransaction(id));
  });

  test('delete a single normal transaction', () async {
    final id = await save(spend(-1500));
    await roundTrip(() => service.deleteTransaction(id));
  });

  test('delete a split (parent and every line)', () async {
    final id = await save(
      TransactionInput(
        accountId: checking,
        date: day,
        amount: -5000,
        splits: [
          SplitLineInput(amount: -3000, categoryId: groceries),
          SplitLineInput(amount: -2000, categoryId: dining),
        ],
      ),
    );
    await roundTrip(() => service.deleteTransaction(id));
  });

  test('edit a split (lines and amount)', () async {
    final id = await save(
      TransactionInput(
        accountId: checking,
        date: day,
        amount: -5000,
        splits: [
          SplitLineInput(amount: -3000, categoryId: groceries),
          SplitLineInput(amount: -2000, categoryId: dining),
        ],
      ),
    );
    await roundTrip(
      () => save(
        TransactionInput(
          id: id,
          accountId: checking,
          date: day,
          amount: -7000,
          splits: [
            SplitLineInput(amount: -1000, categoryId: groceries),
            SplitLineInput(amount: -6000, categoryId: dining),
          ],
        ),
      ),
    );
  });

  test('edit a transfer (amount, both legs)', () async {
    final id = await save(
      TransactionInput(
        accountId: checking,
        date: day,
        amount: -20000,
        transferAccountId: savings,
      ),
    );
    await roundTrip(
      () => save(
        TransactionInput(
          id: id,
          accountId: checking,
          date: day,
          amount: -25000,
          transferAccountId: savings,
        ),
      ),
    );
  });

  test('approve and mark as reconciled', () async {
    final a = (await service.save(
      TransactionInput(
        accountId: checking,
        date: day,
        amount: -1000,
        categoryId: groceries,
        approved: false,
      ),
    )).id;
    await roundTrip(() => service.bulkApprove([a]));
    await roundTrip(() => service.markAsReconciled([a]));
  });

  test('delete several transactions at once', () async {
    final a = await save(spend(-1000));
    final b = await save(spend(-2000, categoryId: dining));
    await roundTrip(() => service.deleteMany([a, b]));
  });

  test('bulk categorise', () async {
    final a = await save(spend(-1000));
    final b = await save(spend(-2000));
    await roundTrip(() => service.bulkCategorize([a, b], dining));
  });

  test('clearing status and approval', () async {
    final a = await save(spend(-1000));
    await roundTrip(
      () => service.updateClearingStatus(a, TransactionClearStatus.cleared),
    );
    await roundTrip(() => service.bulkReject([a]));
  });

  test('reconcile with an adjustment', () async {
    final a = await save(spend(-1000));
    await service.updateClearingStatus(a, TransactionClearStatus.cleared);
    await roundTrip(
      () => service.reconcile(
        accountId: checking,
        statementDate: day,
        statementBalance: 98000, // 990.00 cleared -> 10.00 adjustment
        adjustmentMemo: 'Adjustment',
        clearedBalanceUpTo: (id, upTo) =>
            t.accounts.getClearedBalance(id, upTo: upTo),
      ),
    );
  });

  test('change a budgeted amount', () async {
    await roundTrip(() async {
      await t.budgeting.setCategoryBudgetedAmount(dining, 12345, month);
      undo.addAction(
        BudgetChangeAction(
          budgetingService: t.budgeting,
          categoryId: dining,
          month: month,
          oldAmount: 0,
          newAmount: 12345,
        ),
      );
    });
  });

  test('move money between categories', () async {
    await t.budgeting.setCategoryBudgetedAmount(groceries, 30000, month);
    await roundTrip(() async {
      await t.budgeting.moveMoney(groceries, dining, 10000, month);
      undo.addAction(
        MoveMoneyAction(
          budgetingService: t.budgeting,
          fromCategoryId: groceries,
          toCategoryId: dining,
          amount: 10000,
          month: month,
        ),
      );
    });
  });

  test('moveMoney keeps TBB and the invariant', () async {
    final tbb = await t.budgeting.calculateTBB(month);
    await t.budgeting.moveMoney(groceries, dining, 10000, month);
    expect(await t.budgeting.calculateTBB(month), tbb);
    expect(await t.budgeting.calculateCategoryAvailable(dining, month), 10000);
    await expectLedgerInvariant(t, month);
  });
}
