import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('Transaction Validation', () {
    test('validate returns error for zero amount', () {
      final transaction = Transaction(
        id: const Uuid().v4(),
        accountId: 'acc1',
        date: DateTime.now(),
        amount: 0.0,
      );

      final errors = transaction.validate();
      expect(errors, contains('Transaction amount cannot be zero'));
    });

    test('validate returns empty list for valid transaction', () {
      final transaction = Transaction(
        id: const Uuid().v4(),
        accountId: 'acc1',
        date: DateTime.now(),
        amount: 100.0,
      );

      final errors = transaction.validate();
      expect(errors, isEmpty);
    });
  });
}
