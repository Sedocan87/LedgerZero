import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/screens/reports/providers/report_providers.dart';
import 'package:ledger_zero/presentation/widgets/charts/multi_line_chart.dart';
import 'package:ledger_zero/presentation/widgets/charts/simple_bar_chart.dart';
import 'package:ledger_zero/app/theme.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dateRange = ref.watch(reportDateRangeProvider);
    final dateFormat = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reports),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () async {
              final newRange = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                initialDateRange: dateRange,
              );
              if (newRange != null) {
                ref.read(reportDateRangeProvider.notifier).state = newRange;
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date Range Display
          Text(
            '${dateFormat.format(dateRange.start)} - ${dateFormat.format(dateRange.end)}',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Spending by Category
          Text(l10n.spendingByCategory, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _SpendingChart(),
          const SizedBox(height: 32),

          // Income vs Expense
          Text(l10n.incomeVsExpense, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _IncomeExpenseChart(),
          const SizedBox(height: 32),

          // Net Worth
          Text(l10n.netWorth, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _NetWorthChart(),
        ],
      ),
    );
  }
}

class _SpendingChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spendingAsync = ref.watch(spendingByCategoryProvider);

    return spendingAsync.when(
      data: (data) => SimpleBarChart(
        data: data,
        barColor: AppColors.primaryLight, // Using fixed color from theme constants
        labelColor: Theme.of(context).colorScheme.onSurface,
      ),
      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      error: (e, st) => SizedBox(height: 200, child: Center(child: Text('Error: $e'))),
    );
  }
}

class _IncomeExpenseChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(incomeVsExpenseHistoryProvider);

    return historyAsync.when(
      data: (series) => MultiLineChart(
        seriesList: series,
        gridColor: Theme.of(context).dividerColor,
        labelColor: Theme.of(context).colorScheme.onSurface,
      ),
      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      error: (e, st) => SizedBox(height: 200, child: Center(child: Text('Error: $e'))),
    );
  }
}

class _NetWorthChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(netWorthHistoryProvider);

    return historyAsync.when(
      data: (series) => MultiLineChart(
        seriesList: series,
        gridColor: Theme.of(context).dividerColor,
        labelColor: Theme.of(context).colorScheme.onSurface,
      ),
      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      error: (e, st) => SizedBox(height: 200, child: Center(child: Text('Error: $e'))),
    );
  }
}
