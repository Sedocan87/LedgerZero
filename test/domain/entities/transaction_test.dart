import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';

void main() {
  group('Transaction', () {
    final testDate = DateTime(2023, 1, 1);

    // Using non-const for DateTimes
    final transaction = Transaction(
      id: 'tx_1',
      accountId: 'acc_1',
      date: testDate,
      amount: -50.0,
      payeeId: 'payee_1',
      categoryId: 'cat_1',
      memo: 'Groceries',
      cleared: TransactionClearStatus.cleared,
      approved: true,
      isDeleted: false,
      createdAt: testDate,
      updatedAt: testDate,
    );

    test('supports value equality', () {
      final t1 = Transaction(
        id: 'tx_1',
        accountId: 'acc_1',
        date: testDate,
        amount: -50.0,
        payeeId: 'payee_1',
        categoryId: 'cat_1',
        memo: 'Groceries',
        cleared: TransactionClearStatus.cleared,
        approved: true,
        isDeleted: false,
        createdAt: testDate,
        updatedAt: testDate,
      );
      final t2 = Transaction(
        id: 'tx_1',
        accountId: 'acc_1',
        date: testDate,
        amount: -50.0,
        payeeId: 'payee_1',
        categoryId: 'cat_1',
        memo: 'Groceries',
        cleared: TransactionClearStatus.cleared,
        approved: true,
        isDeleted: false,
        createdAt: testDate,
        updatedAt: testDate,
      );

      expect(t1, equals(t2));
      expect(t1.hashCode, equals(t2.hashCode));
    });

    test('copyWith returns new instance with updated fields', () {
      final updated = transaction.copyWith(amount: -60.0, memo: 'Supermarket');

      expect(updated.amount, equals(-60.0));
      expect(updated.memo, equals('Supermarket'));
      expect(updated.id, equals(transaction.id));
      expect(updated.date, equals(transaction.date));
    });

    test('fromJson creates correct instance', () {
      final json = {
        'id': 'tx_1',
        'account_id': 'acc_1',
        'date': testDate.toIso8601String(),
        'amount': -50.0,
        'payee_id': 'payee_1',
        'category_id': 'cat_1',
        'memo': 'Groceries',
        'cleared': TransactionClearStatus.cleared.index, // 1
        'approved': true,
        'is_deleted': false,
        'transfer_account_id': null,
        'transfer_transaction_id': null,
        'parent_transaction_id': null,
        'created_at': testDate.toIso8601String(),
        'updated_at': testDate.toIso8601String(),
      };

      final t = Transaction.fromJson(json);
      expect(t, equals(transaction));
    });

    test('toJson returns correct map', () {
      final json = transaction.toJson();
      expect(json, {
        'id': 'tx_1',
        'account_id': 'acc_1',
        'date': testDate.toIso8601String(),
        'amount': -50.0,
        'payee_id': 'payee_1',
        'category_id': 'cat_1',
        'memo': 'Groceries',
        'cleared': 1,
        'approved': true,
        'is_deleted': false,
        'transfer_account_id': null,
        'transfer_transaction_id': null,
        'parent_transaction_id': null,
        'created_at': testDate.toIso8601String(),
        'updated_at': testDate.toIso8601String(),
      });
    });

    test('validate returns error for zero amount', () {
      final invalidT = transaction.copyWith(amount: 0.0);
      final errors = invalidT.validate();
      expect(errors, contains('Transaction amount cannot be zero'));
    });

    test('defaults are set correctly', () {
      final defaultT = Transaction(
        id: '1',
        accountId: 'a1',
        date: testDate,
        amount: 10.0,
      );
      expect(defaultT.cleared, TransactionClearStatus.uncleared);
      expect(defaultT.approved, true);
      expect(defaultT.isDeleted, false);
    });
  });
}
