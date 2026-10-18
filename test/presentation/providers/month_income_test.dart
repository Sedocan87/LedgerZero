import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';

import '../../helpers/test_database.dart';

/// The income line's "expected" counts the recurring inflows still to come
/// this month, not occurrences whose date has already passed.
void main() {
  late TestDatabase t;
  late ProviderContainer container;
  final month = DateTime.utc(2026, 10);

  setUp(() async {
    t = TestDatabase();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(t.db),
        todayProvider.overrideWith(
          (ref) => TodayController(clock: () => DateTime(2026, 10, 18, 9)),
        ),
      ],
    );
    await t.addAccount(id: 'a');
  });

  tearDown(() async {
    container.dispose();
    await t.close();
  });

  Future<void> salary(String id, DateTime nextDate, int amount) =>
      t.scheduledTransactions.createScheduledTransaction(
        ScheduledTransaction(
          id: id,
          accountId: 'a',
          amount: amount,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          nextDate: nextDate,
        ),
      );

  Future<MonthIncome> income() {
    final sub = container.listen(monthIncomeProvider(month), (_, _) {});
    addTearDown(sub.close);
    return container.read(monthIncomeProvider(month).future);
  }

  test('only occurrences from today on are expected', () async {
    await salary('overdue', DateTime.utc(2026, 10, 5), 100000);
    await salary('coming', DateTime.utc(2026, 10, 25), 250000);
    final result = await income();
    expect(result.hasRecurringIncome, isTrue);
    expect(result.expected, 250000);
    expect(result.nextExpectedDate, DateTime.utc(2026, 10, 25));
  });

  test('an occurrence today still counts', () async {
    await salary('today', DateTime.utc(2026, 10, 18), 100000);
    expect((await income()).expected, 100000);
  });
}
