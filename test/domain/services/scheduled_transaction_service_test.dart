import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/constants/deterministic_id.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/repositories/scheduled_transaction_repository.dart';
import 'package:ledger_zero/domain/services/scheduled_transaction_service.dart';
import 'package:ledger_zero/domain/services/transaction_service_types.dart';
import 'package:ledger_zero/services/notifications/notification_service.dart';
import 'package:ledger_zero/services/rules/rule_matching_service.dart';

import '../../helpers/test_database.dart';

/// Records notification calls instead of talking to the plugin.
class _FakeNotificationService extends Fake implements NotificationService {
  final scheduled = <int, DateTime>{};
  final cancelled = <int>[];

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    scheduled[id] = scheduledDate;
  }

  @override
  Future<void> cancelNotification(int id) async {
    cancelled.add(id);
  }
}

/// Delegates to the real repository but fails every schedule update for
/// the ids in [failFor] (simulates a crash after the occurrences were
/// written).
class _FailingUpdateRepository implements ScheduledTransactionRepository {
  _FailingUpdateRepository(this._inner, this.failFor);

  final ScheduledTransactionRepository _inner;
  final Set<String> failFor;

  @override
  Future<void> updateScheduledTransaction(ScheduledTransaction t) {
    if (failFor.contains(t.id)) {
      throw StateError('simulated failure while updating ${t.id}');
    }
    return _inner.updateScheduledTransaction(t);
  }

  @override
  Future<List<ScheduledTransaction>> getAllScheduledTransactions() =>
      _inner.getAllScheduledTransactions();

  @override
  Future<List<ScheduledTransaction>> getDueScheduledTransactions(
    DateTime date,
  ) => _inner.getDueScheduledTransactions(date);

  @override
  Future<ScheduledTransaction?> getScheduledTransactionById(String id) =>
      _inner.getScheduledTransactionById(id);

  @override
  Future<void> createScheduledTransaction(ScheduledTransaction t) =>
      _inner.createScheduledTransaction(t);

  @override
  Future<void> deleteScheduledTransaction(String id) =>
      _inner.deleteScheduledTransaction(id);

  @override
  Future<void> skipScheduledTransaction(String id) =>
      _inner.skipScheduledTransaction(id);

  @override
  Stream<List<ScheduledTransaction>> watchAllScheduledTransactions() =>
      _inner.watchAllScheduledTransactions();
}

void main() {
  late TestDatabase t;
  late _FakeNotificationService notifications;
  late ScheduledTransactionService service;
  late String accountId;

  final today = DateTime.utc(2024, 5, 15);
  const fallback = 'Scheduled transaction (fallback)';

  ScheduledTransactionService buildService({
    ScheduledTransactionRepository? scheduledRepository,
    bool withRules = true,
  }) => ScheduledTransactionService(
    scheduledRepository ?? t.scheduledTransactions,
    t.transactions,
    notifications,
    unitOfWork: t.unitOfWork,
    ruleMatchingService: withRules
        ? RuleMatchingService(t.payees, t.transactions, t.rules)
        : null,
    accountRepository: t.accounts,
  );

  setUp(() async {
    t = TestDatabase();
    notifications = _FakeNotificationService();
    service = buildService();
    accountId = (await t.addAccount(name: 'Checking')).id;
  });

  tearDown(() => t.close());

  Future<ScheduledTransaction> addSchedule({
    String id = 'sched-1',
    required DateTime nextDate,
    RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
    int amount = -100000,
    String? payeeId,
    String? categoryId,
    String? memo,
    int? occurrenceCount,
    DateTime? endDate,
    bool autoApprove = false,
    String? account = '',
  }) async {
    final schedule = ScheduledTransaction(
      id: id,
      accountId: account == '' ? accountId : account,
      amount: amount,
      payeeId: payeeId,
      categoryId: categoryId,
      memo: memo,
      frequency: frequency,
      interval: 1,
      nextDate: nextDate,
      endDate: endDate,
      occurrenceCount: occurrenceCount,
      autoApprove: autoApprove,
      createdAt: DateTime.utc(2024, 1, 1),
    );
    await t.scheduledTransactions.createScheduledTransaction(schedule);
    return schedule;
  }

  Future<List<Transaction>> occurrences() async {
    final all = await t.transactions.getAllTransactions();
    return all..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<ScheduledTransaction> reload([String id = 'sched-1']) async =>
      (await t.scheduledTransactions.getScheduledTransactionById(id))!;

  String occurrenceId(DateTime date, [String id = 'sched-1']) =>
      DeterministicId.scheduledOccurrence(id, date);

  group('catch-up', () {
    test('creates every due occurrence and advances the schedule', () async {
      await addSchedule(nextDate: DateTime.utc(2024, 3, 15));

      final created = await service.processDueTransactions(today: today);

      expect(created, 3);
      final rows = await occurrences();
      expect(rows.map((r) => r.date), [
        DateTime.utc(2024, 3, 15),
        DateTime.utc(2024, 4, 15),
        DateTime.utc(2024, 5, 15),
      ]);
      expect(rows.map((r) => r.id), [
        occurrenceId(DateTime.utc(2024, 3, 15)),
        occurrenceId(DateTime.utc(2024, 4, 15)),
        occurrenceId(DateTime.utc(2024, 5, 15)),
      ]);
      for (final r in rows) {
        expect(r.accountId, accountId);
        expect(r.amount, -100000);
        expect(r.cleared, TransactionClearStatus.uncleared);
        expect(r.approved, isFalse);
      }
      final schedule = await reload();
      expect(schedule.nextDate, DateTime.utc(2024, 6, 15));
      expect(schedule.anchorDay, 15);
    });

    test('month-end schedule keeps its anchor while catching up', () async {
      await addSchedule(nextDate: DateTime.utc(2024, 1, 31));

      await service.processDueTransactions(today: today);

      final rows = await occurrences();
      expect(rows.map((r) => r.date), [
        DateTime.utc(2024, 1, 31),
        DateTime.utc(2024, 2, 29),
        DateTime.utc(2024, 3, 31),
        DateTime.utc(2024, 4, 30),
      ]);
      expect((await reload()).nextDate, DateTime.utc(2024, 5, 31));
    });

    test('a schedule that is not due yet is left alone', () async {
      await addSchedule(nextDate: DateTime.utc(2024, 5, 16));

      expect(await service.processDueTransactions(today: today), 0);
      expect(await occurrences(), isEmpty);
      expect((await reload()).nextDate, DateTime.utc(2024, 5, 16));
    });

    test('autoApprove marks the occurrences approved', () async {
      await addSchedule(nextDate: today, autoApprove: true);

      await service.processDueTransactions(today: today);

      expect((await occurrences()).single.approved, isTrue);
    });

    test('a schedule without account creates nothing', () async {
      await addSchedule(nextDate: today, account: null);

      expect(await service.processDueTransactions(today: today), 0);
      expect(await occurrences(), isEmpty);
      expect((await reload()).nextDate, today);
    });
  });

  group('idempotency', () {
    test('running twice yields exactly one row per occurrence', () async {
      await addSchedule(nextDate: DateTime.utc(2024, 3, 15));

      expect(await service.processDueTransactions(today: today), 3);
      expect(await service.processDueTransactions(today: today), 0);

      expect(await occurrences(), hasLength(3));
      expect((await reload()).nextDate, DateTime.utc(2024, 6, 15));
    });

    test('concurrent runs do not duplicate occurrences', () async {
      await addSchedule(nextDate: DateTime.utc(2024, 3, 15));

      final results = await Future.wait([
        service.processDueTransactions(today: today),
        buildService().processDueTransactions(today: today),
      ]);

      expect(results.reduce((a, b) => a + b), 3);
      expect(await occurrences(), hasLength(3));
      expect((await reload()).nextDate, DateTime.utc(2024, 6, 15));
    });

    test(
      'crash recovery: an occurrence written before a crash is not duplicated',
      () async {
        await addSchedule(nextDate: DateTime.utc(2024, 3, 15));
        // A previous run wrote the April occurrence but the schedule was
        // never advanced (it still points at March 15).
        await t.addTransaction(
          id: occurrenceId(DateTime.utc(2024, 4, 15)),
          accountId: accountId,
          amount: -100000,
          date: DateTime.utc(2024, 4, 15),
        );

        final created = await service.processDueTransactions(today: today);

        expect(created, 2);
        final rows = await occurrences();
        expect(rows, hasLength(3));
        expect(rows.map((r) => r.id).toSet(), hasLength(3));
        expect(
          rows.where((r) => r.date == DateTime.utc(2024, 4, 15)),
          hasLength(1),
        );
        expect((await reload()).nextDate, DateTime.utc(2024, 6, 15));
      },
    );

    test('a second device with a stale schedule creates no duplicates and '
        'does not resurrect a deleted occurrence', () async {
      final original = await addSchedule(nextDate: DateTime.utc(2024, 4, 15));
      await service.processDueTransactions(today: today);
      await t.transactions.deleteTransaction(
        occurrenceId(DateTime.utc(2024, 4, 15)),
      );
      // The other device still has the schedule at April 15.
      await t.scheduledTransactions.updateScheduledTransaction(original);

      expect(await service.processDueTransactions(today: today), 0);

      final rows = await occurrences();
      expect(rows.map((r) => r.date), [DateTime.utc(2024, 5, 15)]);
    });
  });

  group('atomicity', () {
    test('if the schedule update fails no occurrence is committed', () async {
      await addSchedule(id: 'broken', nextDate: DateTime.utc(2024, 3, 15));
      await addSchedule(id: 'healthy', nextDate: today);
      final failing = buildService(
        scheduledRepository: _FailingUpdateRepository(t.scheduledTransactions, {
          'broken',
        }),
      );

      final created = await failing.processDueTransactions(today: today);

      // The healthy schedule is still processed.
      expect(created, 1);
      final rows = await occurrences();
      expect(rows.map((r) => r.id), [occurrenceId(today, 'healthy')]);
      expect(
        (await reload('broken')).nextDate,
        DateTime.utc(2024, 3, 15),
        reason: 'the failed schedule is not advanced',
      );
      expect((await reload('healthy')).nextDate, DateTime.utc(2024, 6, 15));

      // A later healthy run completes the broken schedule exactly once.
      expect(await service.processDueTransactions(today: today), 3);
      expect(await occurrences(), hasLength(4));
    });
  });

  group('memo and payee', () {
    test('uses the schedule memo', () async {
      await addSchedule(nextDate: today, memo: 'Rent May');

      await service.processDueTransactions(
        today: today,
        fallbackMemo: fallback,
      );

      expect((await occurrences()).single.memo, 'Rent May');
    });

    test('falls back to the localised memo without memo and payee', () async {
      await addSchedule(nextDate: today);

      await service.processDueTransactions(
        today: today,
        fallbackMemo: fallback,
      );

      expect((await occurrences()).single.memo, fallback);
    });

    test('a blank schedule memo counts as no memo', () async {
      await addSchedule(nextDate: today, memo: '   ');

      await service.processDueTransactions(
        today: today,
        fallbackMemo: fallback,
      );

      expect((await occurrences()).single.memo, fallback);
    });

    test('a payee without memo leaves the memo empty', () async {
      await t.payees.createPayee(const Payee(id: 'p1', name: 'Landlord'));
      await addSchedule(nextDate: today, payeeId: 'p1');

      await service.processDueTransactions(
        today: today,
        fallbackMemo: fallback,
      );

      final row = (await occurrences()).single;
      expect(row.payeeId, 'p1');
      expect(row.memo, isNull);
    });

    test('without a fallback the memo stays empty', () async {
      await addSchedule(nextDate: today);

      await service.processDueTransactions(today: today);

      expect((await occurrences()).single.memo, isNull);
    });
  });

  group('rules', () {
    Future<void> addRule(
      String id,
      List<RuleCondition> conditions,
      List<RuleAction> actions, {
      int priority = 0,
    }) => t.rules.createRule(
      Rule(
        id: id,
        name: id,
        priority: priority,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: conditions,
        actions: actions,
      ),
    );

    test('fills an empty category and applies cleared/approved', () async {
      final groceries = await t.categoryId('Groceries');
      await addRule(
        'r1',
        [
          RuleCondition.amount(
            operator: RuleConditionOperator.equals,
            minor: -100000,
          ),
        ],
        [
          RuleAction(type: RuleActionType.setCategory, value: groceries),
          const RuleAction(type: RuleActionType.markCleared, value: 'true'),
          const RuleAction(type: RuleActionType.markApproved, value: 'true'),
        ],
      );
      await addSchedule(nextDate: today);

      await service.processDueTransactions(
        today: today,
        fallbackMemo: fallback,
      );

      final row = (await occurrences()).single;
      expect(row.categoryId, groceries);
      expect(row.cleared, TransactionClearStatus.cleared);
      expect(row.approved, isTrue);
      expect(row.accountId, accountId);
    });

    test('does not override the schedule category or memo', () async {
      final groceries = await t.categoryId('Groceries');
      final rent = await t.categoryId('Rent/Mortgage');
      await addRule(
        'r1',
        [
          const RuleCondition(
            type: RuleConditionType.description,
            operator: RuleConditionOperator.contains,
            value: 'rent',
          ),
        ],
        [
          RuleAction(type: RuleActionType.setCategory, value: groceries),
          const RuleAction(type: RuleActionType.setMemo, value: 'From rule'),
        ],
      );
      await addSchedule(nextDate: today, categoryId: rent, memo: 'Rent');

      await service.processDueTransactions(
        today: today,
        fallbackMemo: fallback,
      );

      final row = (await occurrences()).single;
      expect(row.categoryId, rent);
      expect(row.memo, 'Rent');
    });

    test('a memo set by a rule wins over the fallback memo', () async {
      await addRule(
        'r1',
        [
          RuleCondition.amount(
            operator: RuleConditionOperator.lessThan,
            minor: 0,
          ),
        ],
        [const RuleAction(type: RuleActionType.setMemo, value: 'Outflow')],
      );
      await addSchedule(nextDate: today);

      await service.processDueTransactions(
        today: today,
        fallbackMemo: fallback,
      );

      expect((await occurrences()).single.memo, 'Outflow');
    });

    test('works without a rule matching service', () async {
      await addRule(
        'r1',
        [
          RuleCondition.amount(
            operator: RuleConditionOperator.lessThan,
            minor: 0,
          ),
        ],
        [const RuleAction(type: RuleActionType.setMemo, value: 'Outflow')],
      );
      await addSchedule(nextDate: today);

      await buildService(
        withRules: false,
      ).processDueTransactions(today: today, fallbackMemo: fallback);

      expect((await occurrences()).single.memo, fallback);
    });
  });

  group('finishing', () {
    test(
      'occurrenceCount limits the catch-up and finishes the schedule',
      () async {
        await addSchedule(
          nextDate: DateTime.utc(2024, 3, 15),
          occurrenceCount: 2,
        );

        expect(await service.processDueTransactions(today: today), 2);

        final rows = await occurrences();
        expect(rows.map((r) => r.date), [
          DateTime.utc(2024, 3, 15),
          DateTime.utc(2024, 4, 15),
        ]);
        final schedule = await reload();
        expect(schedule.nextDate, isNull);
        expect(schedule.occurrenceCount, 0);
        expect(
          notifications.cancelled,
          contains(ScheduledTransactionService.reminderId('sched-1')),
        );

        expect(await service.processDueTransactions(today: today), 0);
        expect(await occurrences(), hasLength(2));
      },
    );

    test('occurrenceCount is decremented per created occurrence', () async {
      await addSchedule(
        nextDate: DateTime.utc(2024, 4, 15),
        occurrenceCount: 5,
      );

      await service.processDueTransactions(today: today);

      final schedule = await reload();
      expect(schedule.occurrenceCount, 3);
      expect(schedule.nextDate, DateTime.utc(2024, 6, 15));
    });

    test('the end date finishes the schedule', () async {
      await addSchedule(
        nextDate: DateTime.utc(2024, 3, 15),
        endDate: DateTime.utc(2024, 4, 30),
      );

      expect(await service.processDueTransactions(today: today), 2);

      final schedule = await reload();
      expect(schedule.nextDate, isNull);
      expect(schedule.occurrenceCount, isNull);
    });
  });

  group('skip shares the advance step', () {
    test(
      'skipping the last counted occurrence finishes the schedule',
      () async {
        await addSchedule(
          nextDate: DateTime.utc(2024, 6, 15),
          occurrenceCount: 1,
        );

        await t.scheduledTransactions.skipScheduledTransaction('sched-1');

        final schedule = await reload();
        expect(schedule.nextDate, isNull);
        expect(schedule.occurrenceCount, 0);
        expect(await service.processDueTransactions(today: today), 0);
      },
    );

    test('skip then process creates only the remaining occurrences', () async {
      await addSchedule(
        nextDate: DateTime.utc(2024, 4, 15),
        occurrenceCount: 3,
      );

      await t.scheduledTransactions.skipScheduledTransaction('sched-1');
      expect(await service.processDueTransactions(today: today), 1);

      expect((await occurrences()).single.date, DateTime.utc(2024, 5, 15));
      final schedule = await reload();
      expect(schedule.occurrenceCount, 1);
      expect(schedule.nextDate, DateTime.utc(2024, 6, 15));
    });
  });

  group('notifications', () {
    test('schedules a reminder for the next future occurrence', () async {
      final now = CalendarDate.today();
      await addSchedule(
        nextDate: DateTime.utc(now.year, now.month, now.day - 1),
        frequency: RecurrenceFrequency.weekly,
      );

      expect(await service.processDueTransactions(), 1);

      final next = (await reload()).nextDate!;
      expect(next, DateTime.utc(now.year, now.month, now.day + 6));
      expect(
        notifications.scheduled[ScheduledTransactionService.reminderId(
          'sched-1',
        )],
        DateTime(next.year, next.month, next.day - 1, 9),
      );
    });
  });

  group('saving books what is already due', () {
    ScheduledTransaction salary(DateTime nextDate) => ScheduledTransaction(
      id: 'salary',
      accountId: accountId,
      amount: 300000,
      frequency: RecurrenceFrequency.monthly,
      interval: 1,
      nextDate: nextDate,
      createdAt: DateTime.utc(2024, 1, 1),
    );

    test('a salary due today is booked when it is saved', () async {
      service = ScheduledTransactionService(
        t.scheduledTransactions,
        t.transactions,
        notifications,
        unitOfWork: t.unitOfWork,
        defaultMemo: () => fallback,
      );
      final now = CalendarDate.today();
      await service.saveScheduledTransaction(salary(now), isNew: true);

      final booked = await occurrences();
      expect(booked, hasLength(1));
      expect(booked.single.amount, 300000);
      expect(booked.single.date, now);
      expect(booked.single.memo, fallback);
      final next = (await reload('salary')).nextDate!;
      expect(next.isAfter(now), isTrue);
      // The reminder is for the next payday, not the one just booked.
      expect(
        notifications.scheduled[ScheduledTransactionService.reminderId(
          'salary',
        )],
        DateTime(next.year, next.month, next.day - 1, 9),
      );
    });

    test('a later payday waits', () async {
      final later = CalendarDate.today().add(const Duration(days: 5));
      await service.saveScheduledTransaction(salary(later), isNew: true);
      expect(await occurrences(), isEmpty);
      expect((await reload('salary')).nextDate, later);
    });

    test('editing a schedule to today books it too', () async {
      final now = CalendarDate.today();
      await service.saveScheduledTransaction(
        salary(now.add(const Duration(days: 5))),
        isNew: true,
      );
      await service.saveScheduledTransaction(salary(now), isNew: false);
      expect(await occurrences(), hasLength(1));
    });
  });

  group('amount validation', () {
    ScheduledTransaction schedule(int? amount) => ScheduledTransaction(
      id: 'sched-z',
      accountId: accountId,
      amount: amount,
      frequency: RecurrenceFrequency.monthly,
      interval: 1,
      nextDate: DateTime.utc(2024, 5, 1),
      createdAt: DateTime.utc(2024, 1, 1),
    );

    test('saving a zero or missing amount is a validation error', () async {
      for (final amount in [0, null]) {
        await expectLater(
          service.saveScheduledTransaction(schedule(amount), isNew: true),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.code,
              'code',
              TransactionValidationError.zeroAmount,
            ),
          ),
        );
      }
      expect(
        await t.scheduledTransactions.getAllScheduledTransactions(),
        isEmpty,
      );

      await service.saveScheduledTransaction(schedule(-500), isNew: true);
      expect((await reload('sched-z')).amount, -500);
    });

    test('a stored zero-amount schedule never materialises', () async {
      // Bypasses the service, as an old row or another device could.
      await t.scheduledTransactions.createScheduledTransaction(schedule(0));
      expect(await service.processDueTransactions(today: today), 0);
      expect(await occurrences(), isEmpty);
      expect((await reload('sched-z')).nextDate, DateTime.utc(2024, 5, 1));
    });
  });

  group('skipping moves the reminder', () {
    test('the reminder follows the new next occurrence; finishing cancels '
        'it', () async {
      final next = CalendarDate.today().add(const Duration(days: 10));
      await addSchedule(nextDate: next, occurrenceCount: 2);
      final id = ScheduledTransactionService.reminderId('sched-1');

      await service.skipOccurrence('sched-1');
      final after = await reload();
      expect(after.nextDate, isNot(next));
      final due = after.nextDate!;
      expect(
        notifications.scheduled[id],
        DateTime(due.year, due.month, due.day - 1, 9),
      );

      notifications.cancelled.clear();
      await service.skipOccurrence('sched-1');
      expect((await reload()).nextDate, isNull);
      expect(notifications.cancelled, contains(id));
    });
  });

  group('closed accounts, end date and catch-up cap (L3, L7)', () {
    test('a closed account takes no bookings until it is reopened', () async {
      await addSchedule(nextDate: DateTime.utc(2024, 3, 15));
      final account = (await t.accounts.getAccountById(accountId))!;
      await t.accounts.updateAccount(account.copyWith(isClosed: true));

      expect(await service.processDueTransactions(today: today), 0);
      expect(await occurrences(), isEmpty);
      expect((await reload()).nextDate, DateTime.utc(2024, 3, 15));

      await t.accounts.updateAccount(account.copyWith(isClosed: false));
      expect(await service.processDueTransactions(today: today), 3);
    });

    test("the partner's personal account takes no bookings", () async {
      // As it arrives from the partner's phone: owned by another member.
      final partner = (await t.addAccount(name: 'Partner')).id;
      await t.db.customStatement(
        'UPDATE accounts SET owner_id = ?, on_budget = 0 WHERE id = ?',
        ['partner-member', partner],
      );
      expect((await t.accounts.getAccountById(partner))!.isPartners, isTrue);
      await addSchedule(nextDate: today, account: partner);
      expect(await service.processDueTransactions(today: today), 0);
      expect(await occurrences(), isEmpty);
    });

    test('a next date after the end date finishes the schedule without '
        'booking', () async {
      await addSchedule(
        nextDate: DateTime.utc(2024, 5, 10),
        endDate: DateTime.utc(2024, 5, 1),
      );
      expect(await service.processDueTransactions(today: today), 0);
      expect(await occurrences(), isEmpty);
      expect((await reload()).nextDate, isNull);
    });

    test('saving an end date before the next date is rejected', () async {
      await expectLater(
        service.saveScheduledTransaction(
          isNew: true,
          ScheduledTransaction(
            id: 'bad',
            accountId: accountId,
            amount: -100,
            frequency: RecurrenceFrequency.monthly,
            nextDate: DateTime.utc(2024, 5, 10),
            endDate: DateTime.utc(2024, 5, 1),
          ),
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.code,
            'code',
            TransactionValidationError.scheduleEndBeforeNextDate,
          ),
        ),
      );
      expect(
        await t.scheduledTransactions.getScheduledTransactionById('bad'),
        isNull,
      );
    });

    test(
      'one run books at most 31 occurrences; the next run continues',
      () async {
        await addSchedule(
          nextDate: DateTime.utc(2024, 3, 1),
          frequency: RecurrenceFrequency.daily,
        );
        // 1 March .. 15 May = 76 due days.
        expect(await service.processDueTransactions(today: today), 31);
        expect((await reload()).nextDate, DateTime.utc(2024, 4, 1));
        expect(await service.processDueTransactions(today: today), 31);
        expect(await service.processDueTransactions(today: today), 14);
        expect((await occurrences()).length, 76);
        expect((await reload()).nextDate, DateTime.utc(2024, 5, 16));
      },
    );
  });
}
