import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/screens/reports/providers/report_providers.dart';
import 'package:ledger_zero/presentation/screens/reports/widgets/report_date_selector.dart';
import 'package:ledger_zero/presentation/widgets/charts/multi_line_chart.dart';
import 'package:ledger_zero/presentation/widgets/charts/pie_chart.dart';
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
        actions: const [
          ReportDateSelector(),
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

          // Spending Trends (Compare Months) - Task 305
          Text(l10n.spendingTrends, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _SpendingTrendsChart(),
          const SizedBox(height: 32),

          // Spending by Category (Bar Chart)
          Text(l10n.spendingByCategory, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _SpendingChart(),
          const SizedBox(height: 32),

          // Category Breakdown (Pie Chart) - Task 307
          Text(l10n.categoryBreakdown, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _CategoryPieChart(),
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
          const SizedBox(height: 32),

          // Top Payees - Task 306
          Text(l10n.topPayees, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _TopPayeesList(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SpendingTrendsChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendsAsync = ref.watch(spendingTrendsProvider);

    return trendsAsync.when(
      data: (data) {
        if (data.isEmpty) return const SizedBox(height: 200, child: Center(child: Text("No data")));

        final sortedKeys = data.keys.toList()..sort();
        final chartData = <String, double>{};

        // If range spans multiple years, show year in label
        final multiYear = data.keys.isNotEmpty &&
            (data.keys.first.year != data.keys.last.year);

        for (var date in sortedKeys) {
          final label = multiYear
              ? DateFormat.yMMM().format(date)
              : DateFormat.MMM().format(date);
          chartData[label] = data[date]!;
        }

        return SimpleBarChart(
          data: chartData,
          barColor: AppColors.secondaryLight,
          labelColor: Theme.of(context).colorScheme.onSurface,
          preserveOrder: true,
        );
      },
      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      error: (e, st) => SizedBox(height: 200, child: Center(child: Text('Error: $e'))),
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
        barColor: AppColors.primaryLight,
        labelColor: Theme.of(context).colorScheme.onSurface,
      ),
      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      error: (e, st) => SizedBox(height: 200, child: Center(child: Text('Error: $e'))),
    );
  }
}

class _CategoryPieChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spendingAsync = ref.watch(spendingByCategoryProvider);

    return spendingAsync.when(
      data: (data) => PieChart(
        data: data,
        labelColor: Theme.of(context).colorScheme.onSurface,
      ),
      loading: () => const SizedBox(height: 300, child: Center(child: CircularProgressIndicator())),
      error: (e, st) => SizedBox(height: 300, child: Center(child: Text('Error: $e'))),
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

class _TopPayeesList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payeesAsync = ref.watch(topPayeesProvider);
    final currencyFormat = NumberFormat.simpleCurrency(decimalDigits: 0);

    return payeesAsync.when(
      data: (data) {
        if (data.isEmpty) return const SizedBox(height: 100, child: Center(child: Text("No payee data")));

        return Card(
           child: Column(
             children: data.map((entry) {
               return ListTile(
                 title: Text(entry.key),
                 trailing: Text(
                     currencyFormat.format(entry.value),
                     style: TextStyle(
                         fontWeight: FontWeight.bold,
                         color: Theme.of(context).colorScheme.onSurface
                     )
                 ),
                 dense: true,
               );
             }).toList(),
           ),
        );
      },
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      error: (e, st) => SizedBox(height: 100, child: Center(child: Text('Error: $e'))),
    );
  }
}
