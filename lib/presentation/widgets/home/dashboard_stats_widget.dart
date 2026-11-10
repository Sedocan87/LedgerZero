import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/month_selector.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';
import 'package:ledger_zero/presentation/widgets/home/dashboard_stats_card.dart';

final monthlyStatsProvider = FutureProvider.autoDispose
    .family<Map<String, int>, DateTime>((ref, month) async {
      ref.watch(ledgerChangesProvider);

      final budgetingService = ref.watch(budgetingServiceProvider);
      final income = await budgetingService.calculateTotalIncomeForMonth(month);
      // The service sums outflows as a negative amount; the card is headed
      // "Total Spending", so it shows what was spent (a month with more
      // refunds than spending shows a negative amount).
      final spending = -await budgetingService.calculateTotalSpendingForMonth(
        month,
      );
      return {'income': income, 'spending': spending};
    });

/// The month shown on the home screen (first day, UTC midnight). Defaults
/// to the current month and follows it ([followCurrentMonth]).
final selectedHomeMonthProvider = StateProvider<DateTime>(followCurrentMonth);

class DashboardStatsWidget extends ConsumerStatefulWidget {
  const DashboardStatsWidget({super.key});

  @override
  ConsumerState<DashboardStatsWidget> createState() =>
      _DashboardStatsWidgetState();
}

class _DashboardStatsWidgetState extends ConsumerState<DashboardStatsWidget>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // A new day (or month) may have started while in the background.
      ref.read(todayProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(selectedHomeMonthProvider);
    final currentMonth = ref.watch(currentMonthProvider);
    final statsAsync = ref.watch(monthlyStatsProvider(selectedMonth));
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = AppSemanticColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The month of the tiles below, without a frame; it cannot go past
        // the current month.
        MonthSwitcher(
          month: selectedMonth,
          canGoNext: selectedMonth.isBefore(currentMonth),
          onChanged: (month) =>
              ref.read(selectedHomeMonthProvider.notifier).state = month,
          onPick: () async {
            final picked = await showMonthPicker(
              context,
              initial: selectedMonth,
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              ref.read(selectedHomeMonthProvider.notifier).state = picked;
            }
          },
        ),
        const SizedBox(height: 4),
        // Stats cards
        statsAsync.when(
          skipLoadingOnReload: true,
          data: (stats) {
            return Row(
              children: [
                // Income in the success colour; spending in the text colour
                // (colour marks state, not every outflow).
                DashboardStatsCard(
                  title: l10n.totalIncome,
                  amount: stats['income']!,
                  icon: Icons.arrow_downward_rounded,
                  iconColor: colors.income,
                  amountColor: colors.income,
                ),
                const SizedBox(width: 12),
                DashboardStatsCard(
                  title: l10n.totalSpending,
                  amount: stats['spending']!,
                  icon: Icons.arrow_upward_rounded,
                  iconColor: theme.colorScheme.onSurfaceVariant,
                  amountColor: theme.colorScheme.onSurface,
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
