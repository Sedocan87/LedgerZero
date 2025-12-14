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
        interval: 2,
        occurrenceCount: 5,
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
      expect(scheduledTransaction.interval, 2);
      expect(scheduledTransaction.occurrenceCount, 5);
      expect(scheduledTransaction.nextDate, now);
      expect(scheduledTransaction.endDate, now);
      expect(scheduledTransaction.autoApprove, true);
      expect(scheduledTransaction.createdAt, now);
    });

    test('should use default values', () {
      const scheduledTransaction = ScheduledTransaction(id: '1');

      expect(scheduledTransaction.id, '1');
      expect(scheduledTransaction.accountId, isNull);
      expect(scheduledTransaction.payeeId, isNull);
      expect(scheduledTransaction.categoryId, isNull);
      expect(scheduledTransaction.amount, isNull);
      expect(scheduledTransaction.frequency, isNull);
      expect(scheduledTransaction.interval, isNull);
      expect(scheduledTransaction.occurrenceCount, isNull);
      expect(scheduledTransaction.nextDate, isNull);
      expect(scheduledTransaction.endDate, isNull);
      expect(scheduledTransaction.autoApprove, false);
      expect(scheduledTransaction.createdAt, isNull);
    });

    test('should support serialization', () {
      final now = DateTime(2023, 10, 1);
      final scheduledTransaction = ScheduledTransaction(
        id: '1',
        accountId: 'acc1',
        payeeId: 'payee1',
        categoryId: 'cat1',
        amount: 100.0,
        frequency: RecurrenceFrequency.monthly,
        interval: 2,
        occurrenceCount: 5,
        nextDate: now,
        endDate: now,
        autoApprove: true,
        createdAt: now,
      );

      final json = scheduledTransaction.toJson();
      expect(json['id'], '1');
      expect(json['account_id'], 'acc1');
      expect(json['payee_id'], 'payee1');
      expect(json['category_id'], 'cat1');
      expect(json['amount'], 100.0);
      expect(json['frequency'], 'monthly');
      expect(json['interval'], 2);
      expect(json['occurrence_count'], 5);
      expect(json['next_date'], now.toIso8601String());
      expect(json['end_date'], now.toIso8601String());
      expect(json['auto_approve'], true);
      expect(json['created_at'], now.toIso8601String());

      final fromJson = ScheduledTransaction.fromJson(json);
      expect(fromJson.id, scheduledTransaction.id);
      expect(fromJson.accountId, scheduledTransaction.accountId);
      expect(fromJson.payeeId, scheduledTransaction.payeeId);
      expect(fromJson.categoryId, scheduledTransaction.categoryId);
      expect(fromJson.amount, scheduledTransaction.amount);
      expect(fromJson.frequency, scheduledTransaction.frequency);
      expect(fromJson.interval, scheduledTransaction.interval);
      expect(fromJson.occurrenceCount, scheduledTransaction.occurrenceCount);
      expect(fromJson.nextDate, scheduledTransaction.nextDate);
      expect(fromJson.endDate, scheduledTransaction.endDate);
      expect(fromJson.autoApprove, scheduledTransaction.autoApprove);
      expect(fromJson.createdAt, scheduledTransaction.createdAt);
    });

    test('should handle missing optional fields during serialization', () {
      final json = {'id': '1'};

      final scheduledTransaction = ScheduledTransaction.fromJson(json);
      expect(scheduledTransaction.id, '1');
      expect(scheduledTransaction.accountId, isNull);
      expect(scheduledTransaction.payeeId, isNull);
      expect(scheduledTransaction.categoryId, isNull);
      expect(scheduledTransaction.amount, isNull);
      expect(scheduledTransaction.frequency, isNull);
      expect(scheduledTransaction.interval, isNull);
      expect(scheduledTransaction.occurrenceCount, isNull);
      expect(scheduledTransaction.nextDate, isNull);
      expect(scheduledTransaction.endDate, isNull);
      expect(scheduledTransaction.autoApprove, false); // Default
      expect(scheduledTransaction.createdAt, isNull);
    });

    test('should support equality', () {
      final now = DateTime(2023, 10, 1);
      final scheduledTransaction1 = ScheduledTransaction(
        id: '1',
        accountId: 'acc1',
        payeeId: 'payee1',
        categoryId: 'cat1',
        amount: 100.0,
        frequency: RecurrenceFrequency.monthly,
        interval: 2,
        occurrenceCount: 5,
        nextDate: now,
        endDate: now,
        autoApprove: true,
        createdAt: now,
      );

      final scheduledTransaction2 = ScheduledTransaction(
        id: '1',
        accountId: 'acc1',
        payeeId: 'payee1',
        categoryId: 'cat1',
        amount: 100.0,
        frequency: RecurrenceFrequency.monthly,
        interval: 2,
        occurrenceCount: 5,
        nextDate: now,
        endDate: now,
        autoApprove: true,
        createdAt: now,
      );

      const scheduledTransaction3 = ScheduledTransaction(
        id: '2',
        accountId: 'acc2',
      );

      // Reflexive
      expect(scheduledTransaction1, equals(scheduledTransaction1));

      // Symmetric
      expect(scheduledTransaction1, equals(scheduledTransaction2));
      expect(scheduledTransaction2, equals(scheduledTransaction1));

      // HashCode
      expect(
        scheduledTransaction1.hashCode,
        equals(scheduledTransaction2.hashCode),
      );

      // Not Equal
      expect(scheduledTransaction1, isNot(equals(scheduledTransaction3)));
      expect(
        scheduledTransaction1,
        isNot(equals('Not a ScheduledTransaction')),
      );
      expect(scheduledTransaction1, isNot(equals(null)));
    });
  });
}
