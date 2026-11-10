import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/demo/demo_data.dart';
import 'package:ledger_zero/demo/demo_mode.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('the demo household seeds without errors and ends with exactly '
      '\$240.00 to assign; no category is overspent this month', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = demoDatabase();
    addTearDown(db.close);
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(c.dispose);

    await seedDemoData(c);

    final month = CalendarDate.startOfMonthUtc(CalendarDate.today());
    final budgeting = c.read(budgetingServiceProvider);
    expect(await budgeting.calculateTBB(month), demoToBeBudgeted);

    final accounts = await c.read(accountRepositoryProvider).getAllAccounts();
    expect(
      accounts.map((a) => a.name),
      containsAll(['Checking', 'Visa Card', 'Savings', 'Brokerage']),
    );
    final checking = accounts.firstWhere((a) => a.name == 'Checking');
    expect(checking.balance, greaterThan(0));

    final categories = await c
        .read(categoryRepositoryProvider)
        .getAllCategories();
    final available = {
      for (final cat in categories)
        cat.name: await budgeting.calculateCategoryAvailable(cat.id, month),
    };
    expect(available['Vacation'], greaterThan(0));
    expect(
      available.entries.where((e) => e.value < 0).map((e) => e.key),
      isEmpty,
    );
  });
}
