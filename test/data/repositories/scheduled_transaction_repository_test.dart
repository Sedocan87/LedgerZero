// ScheduledTransactionRepositoryImpl on a real in-memory database.
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart'
    as domain;
import 'package:ledger_zero/domain/repositories/scheduled_transaction_repository.dart';

import '../../helpers/test_database.dart';

void main() {
  group('mapping and due query (real database)', () {
    late TestDatabase t;

    setUp(() async {
      t = TestDatabase();
      await t.addAccount(id: 'acc1');
      await t.payees.createPayee(
        Payee(id: 'payee1', name: 'Landlord', createdAt: DateTime.utc(2024)),
      );
    });
    tearDown(() => t.close());

    test('every field survives a create/update round trip', () async {
      final groceries = await t.categoryId('Groceries');
      final schedule = domain.ScheduledTransaction(
        id: 'st1',
        accountId: 'acc1',
        payeeId: 'payee1',
        categoryId: groceries,
        amount: 10000,
        frequency: domain.RecurrenceFrequency.monthly,
        interval: 2,
        occurrenceCount: 5,
        nextDate: DateTime.utc(2024, 1, 1),
        endDate: DateTime.utc(2024, 12, 31),
        autoApprove: true,
      );
      final repo = t.scheduledTransactions;
      await repo.createScheduledTransaction(schedule);
      var loaded = (await repo.getScheduledTransactionById('st1'))!;
      expect(loaded.accountId, 'acc1');
      expect(loaded.payeeId, 'payee1');
      expect(loaded.categoryId, groceries);
      expect(loaded.amount, 10000);
      expect(loaded.frequency, domain.RecurrenceFrequency.monthly);
      expect(loaded.interval, 2);
      expect(loaded.occurrenceCount, 5);
      expect(loaded.nextDate, DateTime.utc(2024, 1, 1));
      expect(loaded.endDate, DateTime.utc(2024, 12, 31));
      expect(loaded.autoApprove, isTrue);

      await repo.updateScheduledTransaction(
        loaded.copyWith(amount: 12000, autoApprove: false),
      );
      loaded = (await repo.getScheduledTransactionById('st1'))!;
      expect(loaded.amount, 12000);
      expect(loaded.autoApprove, isFalse);
      expect(await repo.getAllScheduledTransactions(), hasLength(1));
    });

    test('due query returns schedules due on or before the date', () async {
      final repo = t.scheduledTransactions;
      for (final (id, day) in [('due', 1), ('today', 15), ('later', 20)]) {
        await repo.createScheduledTransaction(
          domain.ScheduledTransaction(
            id: id,
            accountId: 'acc1',
            amount: -100,
            frequency: domain.RecurrenceFrequency.monthly,
            nextDate: DateTime.utc(2024, 3, day),
          ),
        );
      }
      final due = await repo.getDueScheduledTransactions(
        DateTime.utc(2024, 3, 15),
      );
      expect(due.map((s) => s.id).toSet(), {'due', 'today'});
    });
  });

  group('skipScheduledTransaction (real database)', () {
    late TestDatabase t;
    late ScheduledTransactionRepository repo;

    setUp(() {
      t = TestDatabase();
      repo = t.scheduledTransactions;
    });

    tearDown(() => t.close());

    Future<domain.ScheduledTransaction> skip(
      domain.ScheduledTransaction schedule,
    ) async {
      await repo.createScheduledTransaction(schedule);
      await repo.skipScheduledTransaction(schedule.id);
      return (await repo.getScheduledTransactionById(schedule.id))!;
    }

    test('moves to the next date and decrements the count', () async {
      final result = await skip(
        domain.ScheduledTransaction(
          id: 'st1',
          amount: 10000,
          frequency: domain.RecurrenceFrequency.monthly,
          interval: 2,
          occurrenceCount: 5,
          nextDate: DateTime.utc(2023, 1, 1),
        ),
      );
      expect(result.nextDate, DateTime.utc(2023, 3, 1));
      expect(result.occurrenceCount, 4);
    });

    test(
      'skipping the last counted occurrence finishes the schedule',
      () async {
        final result = await skip(
          domain.ScheduledTransaction(
            id: 'st1',
            amount: 10000,
            frequency: domain.RecurrenceFrequency.monthly,
            occurrenceCount: 1,
            nextDate: DateTime.utc(2023, 1, 1),
          ),
        );
        expect(result.nextDate, isNull);
        expect(result.occurrenceCount, 0);
      },
    );

    test('skipping past the end date finishes the schedule', () async {
      final result = await skip(
        domain.ScheduledTransaction(
          id: 'st1',
          amount: 10000,
          frequency: domain.RecurrenceFrequency.weekly,
          nextDate: DateTime.utc(2023, 1, 1),
          endDate: DateTime.utc(2023, 1, 7),
        ),
      );
      expect(result.nextDate, isNull);
      expect(result.occurrenceCount, isNull);
    });

    test('skipping keeps the month-end anchor', () async {
      await repo.createScheduledTransaction(
        domain.ScheduledTransaction(
          id: 'st1',
          amount: 10000,
          frequency: domain.RecurrenceFrequency.monthly,
          nextDate: DateTime.utc(2024, 1, 31),
        ),
      );
      final dates = <DateTime?>[];
      for (var i = 0; i < 3; i++) {
        await repo.skipScheduledTransaction('st1');
        dates.add((await repo.getScheduledTransactionById('st1'))!.nextDate);
      }
      expect(dates, [
        DateTime.utc(2024, 2, 29),
        DateTime.utc(2024, 3, 31),
        DateTime.utc(2024, 4, 30),
      ]);
      expect((await repo.getScheduledTransactionById('st1'))!.anchorDay, 31);
    });

    test('a finished schedule stays finished', () async {
      const finished = domain.ScheduledTransaction(
        id: 'st1',
        amount: 10000,
        frequency: domain.RecurrenceFrequency.monthly,
        occurrenceCount: 0,
      );
      final result = await skip(finished);
      expect(result.nextDate, isNull);
      expect(result.occurrenceCount, 0);
    });

    test('does nothing if the schedule does not exist', () async {
      await repo.skipScheduledTransaction('missing');
      expect(await repo.getAllScheduledTransactions(), isEmpty);
    });
  });

  group('memo and anchor day mapping (real database)', () {
    late TestDatabase t;

    setUp(() => t = TestDatabase());
    tearDown(() => t.close());

    test('round-trips memo and anchorDay', () async {
      final schedule = domain.ScheduledTransaction(
        id: 'st1',
        amount: -5000,
        frequency: domain.RecurrenceFrequency.monthly,
        nextDate: DateTime.utc(2024, 2, 29),
        memo: 'Rent',
        anchorDay: 31,
      );
      await t.scheduledTransactions.createScheduledTransaction(schedule);
      final loaded = (await t.scheduledTransactions.getScheduledTransactionById(
        'st1',
      ))!;
      expect(loaded.memo, 'Rent');
      expect(loaded.anchorDay, 31);
    });
  });
}
