import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/screens/reports/providers/report_providers.dart';
import 'package:ledger_zero/presentation/screens/reports/widgets/report_date_selector.dart';
import 'package:ledger_zero/presentation/widgets/charts/multi_line_chart.dart';
import 'package:ledger_zero/presentation/widgets/charts/pie_chart.dart';
import 'package:ledger_zero/presentation/widgets/charts/simple_bar_chart.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/services/reports/report_export_service.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  final Map<ReportType, GlobalKey> _chartKeys = {
    ReportType.spendingTrends: GlobalKey(),
    ReportType.spendingByCategory: GlobalKey(),
    ReportType.categoryBreakdown: GlobalKey(),
    ReportType.incomeVsExpense: GlobalKey(),
    ReportType.netWorth: GlobalKey(),
    ReportType.topPayees: GlobalKey(),
  };

  Future<void> _exportReport(ReportType type, ExportFormat format, String title) async {
    final l10n = AppLocalizations.of(context)!;

    // Show loading
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.exporting)),
    );

    try {
      Uint8List? imageBytes;
      if (format != ExportFormat.csv) {
        final key = _chartKeys[type];
        if (key?.currentContext != null) {
          final boundary = key!.currentContext!.findRenderObject() as RenderRepaintBoundary?;
          if (boundary != null) {
            // Check if boundary is attached and has size
             if (boundary.debugNeedsPaint) {
                // Should be painted.
             }
             final image = await boundary.toImage(pixelRatio: 3.0);
             final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
             imageBytes = byteData?.buffer.asUint8List();
          }
        }
      }

      dynamic data;
      switch (type) {
        case ReportType.spendingTrends:
          data = ref.read(spendingTrendsProvider).valueOrNull;
          break;
        case ReportType.spendingByCategory:
          data = ref.read(spendingByCategoryProvider).valueOrNull;
          break;
        case ReportType.categoryBreakdown:
          data = ref.read(spendingByCategoryProvider).valueOrNull;
          break;
        case ReportType.incomeVsExpense:
          data = ref.read(incomeVsExpenseHistoryProvider).valueOrNull;
          break;
        case ReportType.netWorth:
          data = ref.read(netWorthHistoryProvider).valueOrNull;
          break;
        case ReportType.topPayees:
          data = ref.read(topPayeesProvider).valueOrNull;
          break;
      }

      if (data == null && format == ExportFormat.csv) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(l10n.exportFailed('No data available'))),
           );
         }
         return;
      }

      final service = ReportExportService();

      List<String>? csvHeaders;
      if (format == ExportFormat.csv) {
        switch (type) {
          case ReportType.spendingTrends:
            csvHeaders = [l10n.date, l10n.amount];
            break;
          case ReportType.spendingByCategory:
          case ReportType.categoryBreakdown:
            csvHeaders = [l10n.category, l10n.amount];
            break;
          case ReportType.incomeVsExpense:
          case ReportType.netWorth:
            csvHeaders = [l10n.series, l10n.date, l10n.amount];
            break;
          case ReportType.topPayees:
            csvHeaders = [l10n.payee, l10n.amount];
            break;
        }
      }

      await service.exportReport(
        type: type,
        format: format,
        data: data,
        imageBytes: imageBytes,
        title: title,
        csvHeaders: csvHeaders,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        // Share plugin handles the feedback usually, but we can show success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportFailed(e.toString()))),
        );
      }
    }
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => _ExportDialog(onExport: _exportReport),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateRange = ref.watch(reportDateRangeProvider);
    final dateFormat = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reports),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: l10n.export,
            onPressed: _showExportDialog,
          ),
          const ReportDateSelector(),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date Range Display
              Text(
                '${dateFormat.format(dateRange.start)} - ${dateFormat.format(dateRange.end)}',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Spending Trends (Compare Months)
              Text(l10n.spendingTrends, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              RepaintBoundary(
                key: _chartKeys[ReportType.spendingTrends],
                child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor, // Ensure background is captured
                    child: _SpendingTrendsChart()
                ),
              ),
              const SizedBox(height: 32),

              // Spending by Category (Bar Chart)
              Text(l10n.spendingByCategory, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              RepaintBoundary(
                key: _chartKeys[ReportType.spendingByCategory],
                child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: _SpendingChart()
                ),
              ),
              const SizedBox(height: 32),

              // Category Breakdown (Pie Chart)
              Text(l10n.categoryBreakdown, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              RepaintBoundary(
                key: _chartKeys[ReportType.categoryBreakdown],
                child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: _CategoryPieChart()
                ),
              ),
              const SizedBox(height: 32),

              // Income vs Expense
              Text(l10n.incomeVsExpense, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              RepaintBoundary(
                key: _chartKeys[ReportType.incomeVsExpense],
                child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: _IncomeExpenseChart()
                ),
              ),
              const SizedBox(height: 32),

              // Net Worth
              Text(l10n.netWorth, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              RepaintBoundary(
                key: _chartKeys[ReportType.netWorth],
                child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: _NetWorthChart()
                ),
              ),
              const SizedBox(height: 32),

              // Top Payees
              Text(l10n.topPayees, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              RepaintBoundary(
                key: _chartKeys[ReportType.topPayees],
                child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: _TopPayeesList()
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportDialog extends StatefulWidget {
  final Function(ReportType, ExportFormat, String) onExport;

  const _ExportDialog({required this.onExport});

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  ReportType _selectedType = ReportType.spendingTrends;
  ExportFormat _selectedFormat = ExportFormat.csv;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final reportTitles = {
      ReportType.spendingTrends: l10n.spendingTrends,
      ReportType.spendingByCategory: l10n.spendingByCategory,
      ReportType.categoryBreakdown: l10n.categoryBreakdown,
      ReportType.incomeVsExpense: l10n.incomeVsExpense,
      ReportType.netWorth: l10n.netWorth,
      ReportType.topPayees: l10n.topPayees,
    };

    return AlertDialog(
      title: Text(l10n.exportReport),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.selectReportToExport, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<ReportType>(
              value: _selectedType,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: ReportType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(reportTitles[type] ?? type.name),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedType = value);
              },
            ),
            const SizedBox(height: 16),
            Text(l10n.exportFormat, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<ExportFormat>(
              segments: [
                ButtonSegment(
                  value: ExportFormat.csv,
                  label: Text(l10n.csv),
                  icon: const Icon(Icons.table_chart),
                ),
                ButtonSegment(
                  value: ExportFormat.pdf,
                  label: Text(l10n.pdf),
                  icon: const Icon(Icons.picture_as_pdf),
                ),
                ButtonSegment(
                  value: ExportFormat.image,
                  label: Text(l10n.image),
                  icon: const Icon(Icons.image),
                ),
              ],
              selected: {_selectedFormat},
              onSelectionChanged: (newSelection) {
                setState(() => _selectedFormat = newSelection.first);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onExport(_selectedType, _selectedFormat, reportTitles[_selectedType]!);
          },
          child: Text(l10n.export),
        ),
      ],
    );
  }
}

// ... existing chart widgets ...
class _SpendingTrendsChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendsAsync = ref.watch(spendingTrendsProvider);

    return trendsAsync.when(
      data: (data) {
        if (data.isEmpty) {
          return const SizedBox(height: 200, child: Center(child: Text('No data')));
        }

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
        if (data.isEmpty) {
          return const SizedBox(height: 100, child: Center(child: Text('No payee data')));
        }

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
