import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';

void main() {
  group('ScheduledTransaction', () {
    test('should instantiate correctly', () {
      final now = DateTime.now();
      final scheduledTransaction = ScheduledTransaction(
        id: '1',
        accountId: 'acc1',
        payeeId: 'payee1',
        categoryId: 'cat1',
        amount: 100.0,
        frequency: RecurrenceFrequency.monthly,
        nextDate: now,
        endDate: now,
        autoApprove: true,
        createdAt: now,
      );

      expect(scheduledTransaction.id, '1');
      expect(scheduledTransaction.accountId, 'acc1');
      expect(scheduledTransaction.payeeId, 'payee1');
      expect(scheduledTransaction.categoryId, 'cat1');
      expect(scheduledTransaction.amount, 100.0);
      expect(scheduledTransaction.frequency, RecurrenceFrequency.monthly);
      expect(scheduledTransaction.nextDate, now);
      expect(scheduledTransaction.endDate, now);
      expect(scheduledTransaction.autoApprove, true);
      expect(scheduledTransaction.createdAt, now);
    });

    test('should use default values', () {
      const scheduledTransaction = ScheduledTransaction(
        id: '1',
      );

      expect(scheduledTransaction.id, '1');
      expect(scheduledTransaction.accountId, isNull);
      expect(scheduledTransaction.payeeId, isNull);
      expect(scheduledTransaction.categoryId, isNull);
      expect(scheduledTransaction.amount, isNull);
      expect(scheduledTransaction.frequency, isNull);
      expect(scheduledTransaction.nextDate, isNull);
      expect(scheduledTransaction.endDate, isNull);
      expect(scheduledTransaction.autoApprove, false);
      expect(scheduledTransaction.createdAt, isNull);
    });
  });
}
