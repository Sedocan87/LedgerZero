import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';
import 'package:ledger_zero/presentation/widgets/home/dashboard_stats_card.dart';

final monthlyStatsProvider = FutureProvider.autoDispose
    .family<Map<String, int>, DateTime>((ref, month) async {
      ref.watch(ledgerChangesProvider);

      final budgetingService = ref.watch(budgetingServiceProvider);
      final income = await budgetingService.calculateTotalIncomeForMonth(month);
      final spending = await budgetingService.calculateTotalSpendingForMonth(
        month,
      );
      return {'income': income, 'spending': spending};
    });

/// The month shown on the home screen (first day, UTC midnight).
final selectedHomeMonthProvider = StateProvider<DateTime>((ref) {
  return CalendarDate.startOfMonthUtc(CalendarDate.today());
});

class DashboardStatsWidget extends ConsumerWidget {
  const DashboardStatsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedHomeMonthProvider);
    final statsAsync = ref.watch(monthlyStatsProvider(selectedMonth));
    final l10n = AppLocalizations.of(context)!;
    final fmt = ref.watch(appFormatterProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final incomeColor = isDark ? Colors.green.shade300 : AppColors.income;
    final expenseColor = isDark ? Colors.red.shade300 : AppColors.expense;

    return Column(
      children: [
        // Month selector capsule
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: AppLocalizations.of(context)!.previousMonth,
                onPressed: () {
                  ref.read(selectedHomeMonthProvider.notifier).state =
                      DateTime.utc(selectedMonth.year, selectedMonth.month - 1);
                },
              ),
              Flexible(
                child: TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: CalendarDate.toLocalDay(selectedMonth),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDatePickerMode: DatePickerMode.year,
                    );
                    if (picked != null) {
                      ref.read(selectedHomeMonthProvider.notifier).state =
                          DateTime.utc(picked.year, picked.month);
                    }
                  },
                  icon: Icon(
                    Icons.calendar_month_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  label: Text(
                    fmt.formatMonthYear(selectedMonth),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: AppLocalizations.of(context)!.nextMonth,
                onPressed: () {
                  final currentMonth = CalendarDate.startOfMonthUtc(
                    CalendarDate.today(),
                  );
                  // Don't allow navigating past current month
                  if (selectedMonth.isBefore(currentMonth)) {
                    ref
                        .read(selectedHomeMonthProvider.notifier)
                        .state = DateTime.utc(
                      selectedMonth.year,
                      selectedMonth.month + 1,
                    );
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Stats cards
        statsAsync.when(
          data: (stats) {
            return Row(
              children: [
                DashboardStatsCard(
                  title: l10n.totalIncome,
                  amount: stats['income']!,
                  icon: Icons.arrow_downward_rounded,
                  iconColor: incomeColor,
                  amountColor: incomeColor,
                ),
                const SizedBox(width: 12),
                DashboardStatsCard(
                  title: l10n.totalSpending,
                  amount: stats['spending']!,
                  icon: Icons.arrow_upward_rounded,
                  iconColor: expenseColor,
                  amountColor: expenseColor,
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) =>
              LoadErrorView(error: err, stackTrace: stack, compact: true),
        ),
      ],
    );
  }
}
