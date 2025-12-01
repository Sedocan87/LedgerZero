import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/widgets/home/dashboard_stats_card.dart';

final monthlyStatsProvider = FutureProvider.autoDispose.family<Map<String, double>, DateTime>((ref, month) async {
  final budgetingService = ref.watch(budgetingServiceProvider);
  final income = await budgetingService.calculateTotalIncomeForMonth(month);
  final spending = await budgetingService.calculateTotalSpendingForMonth(month);
  return {'income': income, 'spending': spending};
});

class DashboardStatsWidget extends ConsumerWidget {
  const DashboardStatsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final statsAsync = ref.watch(monthlyStatsProvider(currentMonth));
    final l10n = AppLocalizations.of(context)!;

    return statsAsync.when(
      data: (stats) {
        return Row(
          children: [
            DashboardStatsCard(
              title: l10n.totalIncome,
              amount: stats['income']!,
              icon: Icons.arrow_downward,
              iconColor: Colors.green,
              amountColor: Colors.green,
            ),
            const SizedBox(width: 16),
            DashboardStatsCard(
              title: l10n.totalSpending,
              amount: stats['spending']!,
              icon: Icons.arrow_upward,
              iconColor: Colors.red,
              amountColor: Colors.red,
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('Error', style: TextStyle(color: Theme.of(context).colorScheme.error)),
    );
  }
}
