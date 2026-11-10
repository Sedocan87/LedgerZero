import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/widgets/home/dashboard_stats_widget.dart';
import 'package:mockito/mockito.dart';

import '../../../mocks/service_mocks.mocks.dart';

void main() {
  test('Home shows what was spent as a positive amount', () async {
    final month = DateTime.utc(2026, 11);
    final budgeting = MockBudgetingService();
    when(
      budgeting.calculateTotalIncomeForMonth(month),
    ).thenAnswer((_) async => 0);
    // The service sums outflows as a negative amount.
    when(
      budgeting.calculateTotalSpendingForMonth(month),
    ).thenAnswer((_) async => -4250);
    final container = ProviderContainer(
      overrides: [
        budgetingServiceProvider.overrideWithValue(budgeting),
        ledgerChangesProvider.overrideWith((ref) => Stream.value(0)),
      ],
    );
    addTearDown(container.dispose);

    // Keep the auto-dispose provider alive while it loads.
    final sub = container.listen(monthlyStatsProvider(month), (_, _) {});
    addTearDown(sub.close);
    final stats = await container.read(monthlyStatsProvider(month).future);
    expect(stats['spending'], 4250);
    expect(stats['income'], 0);
  });
}
