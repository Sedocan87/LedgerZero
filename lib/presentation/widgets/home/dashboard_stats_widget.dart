import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:ledger_zero/presentation/widgets/home/dashboard_stats_card.dart';

final monthlyStatsProvider = FutureProvider.autoDispose
    .family<Map<String, double>, DateTime>((ref, month) async {
      // Re-fetch when transactions change
      ref.watch(transactionUpdateTriggerProvider);

      final budgetingService = ref.watch(budgetingServiceProvider);
      final income = await budgetingService.calculateTotalIncomeForMonth(month);
      final spending = await budgetingService.calculateTotalSpendingForMonth(
        month,
      );
      return {'income': income, 'spending': spending};
    });

/// Provider for the selected month on home screen
final selectedHomeMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

class DashboardStatsWidget extends ConsumerWidget {
  const DashboardStatsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedHomeMonthProvider);
    final statsAsync = ref.watch(monthlyStatsProvider(selectedMonth));
    final l10n = AppLocalizations.of(context)!;
    final currency = ref.watch(settingsProvider).currency;
    final theme = Theme.of(context);

    return Column(
      children: [
        // Month selector row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                ref.read(selectedHomeMonthProvider.notifier).state = DateTime(
                  selectedMonth.year,
                  selectedMonth.month - 1,
                );
              },
            ),
            TextButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedMonth,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDatePickerMode: DatePickerMode.year,
                );
                if (picked != null) {
                  ref.read(selectedHomeMonthProvider.notifier).state = DateTime(
                    picked.year,
                    picked.month,
                  );
                }
              },
              child: Text(
                DateFormat.yMMMM().format(selectedMonth),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                final now = DateTime.now();
                final currentMonth = DateTime(now.year, now.month);
                // Don't allow navigating past current month
                if (selectedMonth.isBefore(currentMonth)) {
                  ref.read(selectedHomeMonthProvider.notifier).state = DateTime(
                    selectedMonth.year,
                    selectedMonth.month + 1,
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Stats cards
        statsAsync.when(
          data: (stats) {
            return Row(
              children: [
                DashboardStatsCard(
                  title: l10n.totalIncome,
                  amount: stats['income']!,
                  icon: Icons.arrow_downward,
                  iconColor: Colors.green,
                  amountColor: Colors.green,
                  currencyCode: currency,
                ),
                const SizedBox(width: 16),
                DashboardStatsCard(
                  title: l10n.totalSpending,
                  amount: stats['spending']!,
                  icon: Icons.arrow_upward,
                  iconColor: Colors.red,
                  amountColor: Colors.red,
                  currencyCode: currency,
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) =>
              Text('Error', style: TextStyle(color: theme.colorScheme.error)),
        ),
      ],
    );
  }
}
