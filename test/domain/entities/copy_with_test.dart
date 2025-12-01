import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/budget.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';

void main() {
  group('Entity copyWith Tests', () {
    test('Account.copyWith should update fields correctly', () {
      const account = Account(
        id: '1',
        name: 'Checking',
        type: AccountType.checking,
        currency: 'USD',
        startingBalance: 100.0,
        currentBalance: 100.0,
        isClosed: false,
      );

      final updated = account.copyWith(
        name: 'Savings',
        currentBalance: 200.0,
      );

      expect(updated.id, account.id);
      expect(updated.name, 'Savings');
      expect(updated.type, account.type);
      expect(updated.currency, account.currency);
      expect(updated.startingBalance, account.startingBalance);
      expect(updated.currentBalance, 200.0);
      expect(updated.isClosed, account.isClosed);
    });

    test('Budget.copyWith should update fields correctly', () {
      const budget = Budget(
        id: '1',
        month: '2023-01',
        budgeted: 100.0,
        activity: 50.0,
        available: 50.0,
      );

      final updated = budget.copyWith(
        budgeted: 200.0,
        available: 150.0,
      );

      expect(updated.id, budget.id);
      expect(updated.month, budget.month);
      expect(updated.budgeted, 200.0);
      expect(updated.activity, budget.activity);
      expect(updated.available, 150.0);
    });

    test('Category.copyWith should update fields correctly', () {
      const category = Category(
        id: '1',
        name: 'Groceries',
        isHidden: false,
      );

      final updated = category.copyWith(
        name: 'Food',
        isHidden: true,
      );

      expect(updated.id, category.id);
      expect(updated.name, 'Food');
      expect(updated.isHidden, true);
    });

    test('CategoryGroup.copyWith should update fields correctly', () {
      const group = CategoryGroup(
        id: '1',
        name: 'Essential',
        sortOrder: 1,
      );

      final updated = group.copyWith(
        name: 'Needs',
        sortOrder: 2,
      );

      expect(updated.id, group.id);
      expect(updated.name, 'Needs');
      expect(updated.sortOrder, 2);
    });

    test('Payee.copyWith should update fields correctly', () {
      const payee = Payee(
        id: '1',
        name: 'Store',
      );

      final updated = payee.copyWith(
        name: 'Supermarket',
      );

      expect(updated.id, payee.id);
      expect(updated.name, 'Supermarket');
    });

    test('ScheduledTransaction.copyWith should update fields correctly', () {
      const scheduled = ScheduledTransaction(
        id: '1',
        amount: 100.0,
        frequency: RecurrenceFrequency.monthly,
      );

      final updated = scheduled.copyWith(
        amount: 150.0,
        frequency: RecurrenceFrequency.weekly,
      );

      expect(updated.id, scheduled.id);
      expect(updated.amount, 150.0);
      expect(updated.frequency, RecurrenceFrequency.weekly);
    });

    test('Transaction.copyWith should update fields correctly', () {
      final now = DateTime.now();
      final transaction = Transaction(
        id: '1',
        accountId: 'acc1',
        date: now,
        amount: -50.0,
        payeeId: 'payee1',
      );

      final updated = transaction.copyWith(
        amount: -60.0,
        payeeId: 'payee2',
        isDeleted: true,
      );

      expect(updated.id, transaction.id);
      expect(updated.accountId, transaction.accountId);
      expect(updated.date, transaction.date);
      expect(updated.amount, -60.0);
      expect(updated.payeeId, 'payee2');
      expect(updated.isDeleted, true);
    });
  });
}
