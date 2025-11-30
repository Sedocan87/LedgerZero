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

    test('should support serialization', () {
      final now = DateTime(2023, 10, 1);
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

      final json = transaction.toJson();
      expect(json['id'], 'tx1');
      expect(json['account_id'], 'acc1');
      expect(json['date'], DateTime(2023, 10, 27).toIso8601String());
      expect(json['amount'], -50.0);
      expect(json['payee_id'], 'payee1');
      expect(json['category_id'], 'cat1');
      expect(json['memo'], 'Groceries');
      expect(json['cleared'], 1); // cleared index is 1
      expect(json['approved'], false);
      expect(json['transfer_account_id'], 'acc2');
      expect(json['transfer_transaction_id'], 'tx2');
      expect(json['created_at'], now.toIso8601String());
      expect(json['updated_at'], now.toIso8601String());

      final fromJson = Transaction.fromJson(json);
      expect(fromJson.id, transaction.id);
      expect(fromJson.accountId, transaction.accountId);
      expect(fromJson.date, transaction.date);
      expect(fromJson.amount, transaction.amount);
      expect(fromJson.payeeId, transaction.payeeId);
      expect(fromJson.categoryId, transaction.categoryId);
      expect(fromJson.memo, transaction.memo);
      expect(fromJson.cleared, transaction.cleared);
      expect(fromJson.approved, transaction.approved);
      expect(fromJson.transferAccountId, transaction.transferAccountId);
      expect(fromJson.transferTransactionId, transaction.transferTransactionId);
      expect(fromJson.createdAt, transaction.createdAt);
      expect(fromJson.updatedAt, transaction.updatedAt);
    });

    test('should handle missing optional fields during serialization', () {
      final json = {
        'id': 'tx1',
        'account_id': 'acc1',
        'date': '2023-10-27T00:00:00.000',
        'amount': -50.0,
      };

      final transaction = Transaction.fromJson(json);
      expect(transaction.id, 'tx1');
      expect(transaction.accountId, 'acc1');
      expect(transaction.date, DateTime(2023, 10, 27));
      expect(transaction.amount, -50.0);
      expect(transaction.payeeId, isNull);
      expect(transaction.categoryId, isNull);
      expect(transaction.memo, isNull);
      expect(transaction.cleared, TransactionClearStatus.uncleared); // Default
      expect(transaction.approved, true); // Default
      expect(transaction.transferAccountId, isNull);
      expect(transaction.transferTransactionId, isNull);
      expect(transaction.createdAt, isNull);
      expect(transaction.updatedAt, isNull);
    });

    test('should support equality', () {
      final now = DateTime(2023, 10, 1);
      final transaction1 = Transaction(
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

      final transaction2 = Transaction(
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

      final transaction3 = Transaction(
        id: 'tx2',
        accountId: 'acc1',
        date: DateTime(2023, 10, 27),
        amount: 100.0,
      );

      // Reflexive
      expect(transaction1, equals(transaction1));

      // Symmetric
      expect(transaction1, equals(transaction2));
      expect(transaction2, equals(transaction1));

      // HashCode
      expect(transaction1.hashCode, equals(transaction2.hashCode));

      // Not Equal
      expect(transaction1, isNot(equals(transaction3)));
      expect(transaction1, isNot(equals('Not a Transaction')));
      expect(transaction1, isNot(equals(null)));
    });
  });
}
