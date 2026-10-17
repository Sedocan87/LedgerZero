import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';

import '../../helpers/test_database.dart';

/// The income line under To Be Budgeted: received inflows plus recurring
/// income still to come, counted like the transactions it will create.
void main() {
  late TestDatabase t;
  late ProviderContainer container;
  // A future month, so every occurrence in it is still to come.
  final month = DateTime.utc(2099, 3, 1);

  setUp(() async {
    t = TestDatabase();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(t.db)],
    );
    await t.addAccount(id: 'giro');
    await t.addAccount(id: 'broker', onBudget: false);
  });

  tearDown(() async {
    container.dispose();
    await t.close();
  });

  Future<void> addSchedule(
    String id, {
    required int amount,
    required DateTime nextDate,
    String accountId = 'giro',
    String? categoryId,
    RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
  }) => t.scheduledTransactions.createScheduledTransaction(
    ScheduledTransaction(
      id: id,
      accountId: accountId,
      categoryId: categoryId,
      amount: amount,
      frequency: frequency,
      interval: 1,
      nextDate: nextDate,
    ),
  );

  Future<MonthIncome> read() async {
    final sub = container.listen(monthIncomeProvider(month), (_, _) {});
    addTearDown(sub.close);
    return container.read(monthIncomeProvider(month).future);
  }

  test('without recurring income nothing is expected', () async {
    await t.addTransaction(
      accountId: 'giro',
      amount: 120000,
      date: DateTime.utc(2099, 3, 3),
    );
    final income = await read();
    expect(income.received, 120000);
    expect(income.expected, 0);
    expect(income.nextExpectedDate, isNull);
    expect(income.hasRecurringIncome, isFalse);
  });

  test(
    'sums the occurrences into To Be Budgeted and finds the next one',
    () async {
      await addSchedule(
        'salary',
        amount: 300000,
        nextDate: DateTime.utc(2099, 2, 25),
      );
      await addSchedule(
        'side job',
        amount: 10000,
        nextDate: DateTime.utc(2099, 3, 6),
        frequency: RecurrenceFrequency.weekly,
      );
      final income = await read();
      // Salary on the 25th, side job on the 6th, 13th, 20th and 27th.
      expect(income.expected, 300000 + 4 * 10000);
      expect(income.nextExpectedDate, DateTime.utc(2099, 3, 6));
      expect(income.hasRecurringIncome, isTrue);
    },
  );

  test('categorised and off-budget income count as set up but not as '
      'expected To Be Budgeted', () async {
    final groceries = await t.categoryId('Groceries');
    await addSchedule(
      'refund',
      amount: 5000,
      nextDate: DateTime.utc(2099, 3, 10),
      categoryId: groceries,
    );
    await addSchedule(
      'dividend',
      amount: 7000,
      nextDate: DateTime.utc(2099, 3, 15),
      accountId: 'broker',
    );
    final income = await read();
    expect(income.expected, 0);
    expect(income.hasRecurringIncome, isTrue);
  });

  test('scheduled outflows are not income', () async {
    await addSchedule(
      'rent',
      amount: -90000,
      nextDate: DateTime.utc(2099, 3, 1),
    );
    final income = await read();
    expect(income.expected, 0);
    expect(income.hasRecurringIncome, isFalse);
  });
}
