import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/extensions/scheduled_transaction_extensions.dart';

void main() {
  group('ScheduledTransactionExtensions', () {
    test('calculateNextOccurrenceDate returns null if nextDate is null', () {
      const transaction = ScheduledTransaction(id: '1', nextDate: null);
      expect(transaction.calculateNextOccurrenceDate(), isNull);
    });

    test('daily recurrence adds interval days', () {
      final transaction = ScheduledTransaction(
        id: '1',
        nextDate: DateTime(2023, 1, 1),
        frequency: RecurrenceFrequency.daily,
        interval: 2,
      );
      expect(transaction.calculateNextOccurrenceDate(), DateTime(2023, 1, 3));
    });

    test('weekly recurrence adds interval weeks', () {
      final transaction = ScheduledTransaction(
        id: '1',
        nextDate: DateTime(2023, 1, 1),
        frequency: RecurrenceFrequency.weekly,
        interval: 2,
      );
      expect(transaction.calculateNextOccurrenceDate(), DateTime(2023, 1, 15));
    });

    test('monthly recurrence handles standard months', () {
      final transaction = ScheduledTransaction(
        id: '1',
        nextDate: DateTime(2023, 1, 15),
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
      );
      expect(transaction.calculateNextOccurrenceDate(), DateTime(2023, 2, 15));
    });

    test(
      'monthly recurrence handles month end overflow (Jan 31 -> Feb 28)',
      () {
        final transaction = ScheduledTransaction(
          id: '1',
          nextDate: DateTime(2023, 1, 31),
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
        );
        expect(
          transaction.calculateNextOccurrenceDate(),
          DateTime(2023, 2, 28),
        );
      },
    );

    test(
      'monthly recurrence handles month end overflow (Jan 31 -> Feb 29 in leap year)',
      () {
        final transaction = ScheduledTransaction(
          id: '1',
          nextDate: DateTime(2024, 1, 31), // 2024 is leap year
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
        );
        expect(
          transaction.calculateNextOccurrenceDate(),
          DateTime(2024, 2, 29),
        );
      },
    );

    test('yearly recurrence adds interval years', () {
      final transaction = ScheduledTransaction(
        id: '1',
        nextDate: DateTime(2023, 5, 10),
        frequency: RecurrenceFrequency.yearly,
        interval: 1,
      );
      expect(transaction.calculateNextOccurrenceDate(), DateTime(2024, 5, 10));
    });

    test('yearly recurrence handles leap year (Feb 29 -> Feb 28)', () {
      final transaction = ScheduledTransaction(
        id: '1',
        nextDate: DateTime(2024, 2, 29),
        frequency: RecurrenceFrequency.yearly,
        interval: 1,
      );
      expect(transaction.calculateNextOccurrenceDate(), DateTime(2025, 2, 28));
    });

    test('returns null if calculated date is after end date', () {
      final transaction = ScheduledTransaction(
        id: '1',
        nextDate: DateTime(2023, 1, 1),
        frequency: RecurrenceFrequency.daily,
        interval: 1,
        endDate: DateTime(
          2023,
          1,
          1,
        ), // Same as nextDate, so next (Jan 2) is after
      );
      expect(transaction.calculateNextOccurrenceDate(), isNull);
    });

    test('returns date if calculated date is on end date', () {
      final transaction = ScheduledTransaction(
        id: '1',
        nextDate: DateTime(2023, 1, 1),
        frequency: RecurrenceFrequency.daily,
        interval: 1,
        endDate: DateTime(2023, 1, 2),
      );
      expect(transaction.calculateNextOccurrenceDate(), DateTime(2023, 1, 2));
    });
  });
}
