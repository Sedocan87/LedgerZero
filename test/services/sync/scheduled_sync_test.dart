// Scheduled transactions in a household: both phones run the catch-up, and
// what one partner did with an occurrence or a schedule must survive the
// other phone booking the same occurrence later (two real databases and
// engines over a fake folder).
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/constants/deterministic_id.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/services/schedule_stamps.dart';
import 'package:ledger_zero/domain/services/scheduled_transaction_service.dart';
import 'package:ledger_zero/services/notifications/notification_service.dart';

import '../../helpers/sync_simulation.dart';

class _SilentNotifications extends Fake implements NotificationService {
  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {}

  @override
  Future<void> cancelNotification(int id) async {}
}

void main() {
  const passphrase = 'correct horse battery staple';
  final due = DateTime.utc(2025, 3, 1);
  final today = DateTime.utc(2025, 3, 1);
  final occurrenceId = DeterministicId.scheduledOccurrence('rent', due);

  late FakeSyncFolder folder;
  late SimDevice a;
  late SimDevice b;

  ScheduledTransactionService service(SimDevice d) =>
      ScheduledTransactionService(
        d.t!.scheduledTransactions,
        d.t!.transactions,
        _SilentNotifications(),
        unitOfWork: d.t!.unitOfWork,
        accountRepository: d.t!.accounts,
      );

  Future<int> catchUp(SimDevice d) =>
      service(d).processDueTransactions(today: today);

  Future<List<Map<String, Object?>>> live(SimDevice d) => d.rows(
    'SELECT id, amount, approved, cleared FROM transactions '
    'WHERE is_deleted = 0',
  );

  Future<int> conflicts(SimDevice d) =>
      d.count('SELECT COUNT(*) FROM sync_conflicts');

  Future<void> expectConverged() async {
    expect(await b.dump(), await a.dump());
  }

  /// Rent on the 1st, known to both phones, not booked yet.
  setUp(() async {
    folder = FakeSyncFolder();
    a = await SimDevice.create(folder);
    b = await SimDevice.create(folder);
    await a.engine.createSyncFolder(passphrase);
    await b.engine.joinSyncFolder(passphrase);
    await a.t!.addAccount(id: 'acc', name: 'Checking');
    await a.t!.scheduledTransactions.createScheduledTransaction(
      ScheduledTransaction(
        id: 'rent',
        accountId: 'acc',
        amount: -90000,
        frequency: RecurrenceFrequency.monthly,
        nextDate: due,
        memo: 'Rent',
      ),
    );
    await syncAll([a, b]);
    // A person's edit is never in the same millisecond as the version it
    // starts from.
    await Future<void>.delayed(const Duration(milliseconds: 5));
  });

  tearDown(() async {
    await a.close();
    await b.close();
  });

  group('phone B books the occurrence before it has pulled', () {
    test('an occurrence A corrected, approved and cleared stays that '
        'way', () async {
      expect(await catchUp(a), 1);
      await a.sync();
      final booked = (await a.t!.transactions.getTransactionById(
        occurrenceId,
      ))!;
      await a.t!.transactions.updateTransaction(
        booked.copyWith(
          amount: -95000,
          approved: true,
          cleared: TransactionClearStatus.cleared,
        ),
      );
      await a.sync();

      expect(await catchUp(b), 1); // B's own, unedited copy
      await syncAll([a, b], rounds: 3);

      const expected = [
        {
          'amount': -95000,
          'approved': 1,
          'cleared': 1, // TransactionClearStatus.cleared
        },
      ];
      for (final d in [a, b]) {
        expect([
          for (final r in await live(d))
            {
              'amount': r['amount'],
              'approved': r['approved'],
              'cleared': r['cleared'],
            },
        ], expected);
        // Nothing a person decided was overwritten: no conflict entries.
        expect(await conflicts(d), 0);
      }
      await expectConverged();
    });

    test('an occurrence A deleted stays deleted', () async {
      expect(await catchUp(a), 1);
      await a.sync();
      await a.exec('UPDATE transactions SET is_deleted = 1 WHERE id = ?', [
        occurrenceId,
      ]);
      await a.sync();

      expect(await catchUp(b), 1);
      await syncAll([a, b], rounds: 3);

      expect(await live(a), isEmpty);
      expect(await live(b), isEmpty);
      expect(await conflicts(b), 0);
      await expectConverged();
    });

    test('an occurrence A skipped is not booked', () async {
      await service(a).skipOccurrence('rent');
      await a.sync();

      expect(await catchUp(b), 1);
      await syncAll([a, b], rounds: 3);

      expect(await live(a), isEmpty);
      expect(await live(b), isEmpty);
      for (final d in [a, b]) {
        final schedule = (await d.t!.scheduledTransactions
            .getScheduledTransactionById('rent'))!;
        expect(schedule.nextDate, DateTime.utc(2025, 4, 1));
      }
      await expectConverged();
    });

    test('a schedule A edited after its occurrence was booked keeps the '
        'edit', () async {
      expect(await catchUp(a), 1);
      final advanced = (await a.t!.scheduledTransactions
          .getScheduledTransactionById('rent'))!;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await a.t!.scheduledTransactions.updateScheduledTransaction(
        advanced.copyWith(amount: -95000),
      );
      await a.sync();

      expect(await catchUp(b), 1);
      await syncAll([a, b], rounds: 3);

      for (final d in [a, b]) {
        final schedule = (await d.t!.scheduledTransactions
            .getScheduledTransactionById('rent'))!;
        expect(schedule.amount, -95000);
        expect(schedule.nextDate, DateTime.utc(2025, 4, 1));
        expect(await live(d), hasLength(1));
      }
      await expectConverged();
    });
  });

  test('both phones booking the same occurrences agree without '
      'conflicts', () async {
    expect(await catchUp(a), 1);
    expect(await catchUp(b), 1);
    await syncAll([a, b], rounds: 3);

    await expectConverged();
    expect(await live(a), hasLength(1));
    expect(await conflicts(a), 0);
    expect(await conflicts(b), 0);
    // Stamped with times that do not depend on which phone ran when.
    final occurrence = (await a.t!.transactions.getTransactionById(
      occurrenceId,
    ))!;
    expect(occurrence.updatedAt, ScheduleStamps.occurrence(due));
    expect(occurrence.updatedAt, DateTime.utc(2025, 2, 28));
  });

  test('a phone that pulls first (the order of an app start with sync) '
      'books nothing the partner already booked or skipped', () async {
    await service(a).skipOccurrence('rent');
    await a.sync();

    await b.sync();
    expect(await catchUp(b), 0);
    await syncAll([a, b]);

    expect(await live(b), isEmpty);
    await expectConverged();
  });
}
