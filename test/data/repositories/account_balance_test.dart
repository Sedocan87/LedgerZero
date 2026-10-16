import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';

import '../../helpers/test_database.dart';

void main() {
  late TestDatabase t;

  setUp(() => t = TestDatabase());
  tearDown(() => t.close());

  test(
    'balance = starting balance + non-deleted, non-split-child rows',
    () async {
      final checking = await t.addAccount(startingBalance: 100000); // 1000.00
      final savings = await t.addAccount(startingBalance: 5000);
      final groceries = await t.categoryId('Groceries');

      await t.addTransaction(accountId: checking.id, amount: 250000); // deposit
      await t.addTransaction(
        accountId: checking.id,
        amount: -4599,
        categoryId: groceries,
      ); // spending
      // Soft-deleted rows do not count.
      await t.addTransaction(
        accountId: checking.id,
        amount: -99999,
        isDeleted: true,
      );
      // A split: the parent carries the total, children must not be counted
      // again.
      final parent = await t.addTransaction(
        accountId: checking.id,
        amount: -3000,
      );
      await t.addTransaction(
        accountId: checking.id,
        amount: -1000,
        parentTransactionId: parent.id,
        categoryId: groceries,
      );
      await t.addTransaction(
        accountId: checking.id,
        amount: -2000,
        parentTransactionId: parent.id,
        categoryId: groceries,
      );
      await t.addTransaction(accountId: savings.id, amount: 10);

      const expectedChecking = 100000 + 250000 - 4599 - 3000;
      const expectedSavings = 5000 + 10;

      expect(await t.accounts.getAccountBalance(checking.id), expectedChecking);
      expect(await t.accounts.getAccountBalances(), {
        checking.id: expectedChecking,
        savings.id: expectedSavings,
      });

      final all = await t.accounts.getAllAccounts();
      expect(
        {for (final a in all) a.id: a.balance},
        {checking.id: expectedChecking, savings.id: expectedSavings},
      );
      expect(
        (await t.accounts.getAccountById(checking.id))!.balance,
        expectedChecking,
      );
    },
  );

  test('accounts without transactions have their starting balance', () async {
    final account = await t.addAccount(startingBalance: -1234);
    expect(await t.accounts.getAccountBalance(account.id), -1234);
    expect(await t.accounts.getAccountBalance('missing'), 0);
  });

  test('exact integer sums: 0.30 - 0.10 - 0.20 is exactly zero', () async {
    final account = await t.addAccount(startingBalance: 30);
    await t.addTransaction(accountId: account.id, amount: -10);
    await t.addTransaction(accountId: account.id, amount: -20);
    expect(await t.accounts.getAccountBalance(account.id), 0);
  });

  test('cleared balance counts only cleared and reconciled rows', () async {
    final account = await t.addAccount(startingBalance: 1000);
    await t.addTransaction(
      accountId: account.id,
      amount: 500,
      cleared: TransactionClearStatus.cleared,
    );
    await t.addTransaction(
      accountId: account.id,
      amount: 300,
      cleared: TransactionClearStatus.reconciled,
    );
    await t.addTransaction(accountId: account.id, amount: 7);
    expect(await t.accounts.getClearedBalance(account.id), 1800);
    expect(await t.accounts.getAccountBalance(account.id), 1807);
  });

  test('watched balances update when transactions change', () async {
    final account = await t.addAccount(startingBalance: 100);
    final stream = t.accounts.watchAllAccounts().map(
      (list) => list.single.balance,
    );
    final expectation = expectLater(stream, emitsInOrder([100, 150]));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await t.addTransaction(accountId: account.id, amount: 50);
    await expectation;
  });

  test('balance is never persisted on save', () async {
    final account = await t.addAccount(startingBalance: 100);
    await t.accounts.updateAccount(account.copyWith(balance: 999999));
    expect(await t.accounts.getAccountBalance(account.id), 100);
  });
}
