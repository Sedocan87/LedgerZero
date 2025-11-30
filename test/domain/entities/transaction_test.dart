import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';

void main() {
  group('Transaction', () {
    test('should instantiate correctly', () {
      final now = DateTime.now();
      final transaction = Transaction(
        id: 'tx1',
        accountId: 'acc1',
        date: DateTime(2023, 10, 27),
        amount: -50.0,
        payeeId: 'payee1',
        categoryId: 'cat1',
        memo: 'Groceries',
        cleared: TransactionClearStatus.cleared,
        approved: false,
        transferAccountId: 'acc2',
        transferTransactionId: 'tx2',
        createdAt: now,
        updatedAt: now,
      );

      expect(transaction.id, 'tx1');
      expect(transaction.accountId, 'acc1');
      expect(transaction.date, DateTime(2023, 10, 27));
      expect(transaction.amount, -50.0);
      expect(transaction.payeeId, 'payee1');
      expect(transaction.categoryId, 'cat1');
      expect(transaction.memo, 'Groceries');
      expect(transaction.cleared, TransactionClearStatus.cleared);
      expect(transaction.approved, false);
      expect(transaction.transferAccountId, 'acc2');
      expect(transaction.transferTransactionId, 'tx2');
      expect(transaction.createdAt, now);
      expect(transaction.updatedAt, now);
    });

    test('should use default values', () {
      final transaction = Transaction(
        id: 'tx2',
        accountId: 'acc1',
        date: DateTime(2023, 10, 27),
        amount: 100.0,
      );

      expect(transaction.id, 'tx2');
      expect(transaction.accountId, 'acc1');
      expect(transaction.date, DateTime(2023, 10, 27));
      expect(transaction.amount, 100.0);
      expect(transaction.payeeId, null);
      expect(transaction.categoryId, null);
      expect(transaction.memo, null);
      expect(transaction.cleared, TransactionClearStatus.uncleared);
      expect(transaction.approved, true);
      expect(transaction.transferAccountId, null);
      expect(transaction.transferTransactionId, null);
      expect(transaction.createdAt, null);
      expect(transaction.updatedAt, null);
    });
  });
}
