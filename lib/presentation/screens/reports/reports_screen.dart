import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/money/money.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/reports/providers/report_providers.dart';
import 'package:ledger_zero/presentation/screens/reports/widgets/budget_vs_actual_chart.dart';
import 'package:ledger_zero/presentation/screens/reports/widgets/report_category_filter.dart';
import 'package:ledger_zero/presentation/screens/reports/widgets/report_date_selector.dart';
import 'package:ledger_zero/presentation/screens/reports/widgets/report_notes_section.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_data_models.dart';
import 'package:ledger_zero/presentation/widgets/charts/multi_line_chart.dart';
import 'package:ledger_zero/presentation/widgets/charts/pie_chart.dart';
import 'package:ledger_zero/presentation/widgets/charts/simple_bar_chart.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_palette.dart';
import 'package:ledger_zero/services/export/csv_sanitizer.dart';
import 'package:ledger_zero/services/reports/report_export_service.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';

enum ReportType {
  spendingTrends,
  spendingByCategory,
  categoryBreakdown,
  incomeVsExpense,
  netWorth,
  topPayees,
  budgetVsActual,
}

enum ExportFormat { csv, pdf, image }

/// `yyyy-MM-dd` of a calendar day, for machine readable exports.
String _isoDay(DateTime day) =>
    '${CalendarDate.monthKey(day)}-${day.day.toString().padLeft(2, '0')}';

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
    ReportType.budgetVsActual: GlobalKey(),
  };

  Future<void> _exportReport(
    ReportType type,
    ExportFormat format,
    String title,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    // Show loading
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.exporting)));

    try {
      Uint8List? imageBytes;
      if (format != ExportFormat.csv) {
        final key = _chartKeys[type];
        if (key?.currentContext != null) {
          final boundary =
              key!.currentContext!.findRenderObject() as RenderRepaintBoundary?;
          if (boundary != null) {
            // Check if boundary is attached and has size
            if (boundary.debugNeedsPaint) {
              // Should be painted.
            }
            final image = await boundary.toImage(pixelRatio: 3.0);
            final byteData = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            imageBytes = byteData?.buffer.asUint8List();
          }
        }
      }

      dynamic data;
      switch (type) {
        case ReportType.spendingTrends:
          data = await _readOnce(spendingTrendsProvider);
          break;
        case ReportType.spendingByCategory:
          data = await _readOnce(spendingByCategoryProvider);
          break;
        case ReportType.categoryBreakdown:
          data = await _readOnce(spendingByCategoryProvider);
          break;
        case ReportType.incomeVsExpense:
          data = await _readOnce(incomeVsExpenseHistoryProvider);
          break;
        case ReportType.netWorth:
          data = await _readOnce(netWorthHistoryProvider);
          break;
        case ReportType.topPayees:
          data = await _readOnce(topPayeesProvider);
          break;
        case ReportType.budgetVsActual:
          data = await _readOnce(budgetVsActualProvider);
          break;
      }

      if (data == null && format == ExportFormat.csv) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.reportNoDataToExport)));
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
          case ReportType.budgetVsActual:
            csvHeaders = [l10n.category, l10n.budgeted, l10n.activity];
            break;
        }
      }

      if (format == ExportFormat.pdf) {
        // PDF Export
        List<String> headers = [];
        List<List<String>> rows = [];
        final fmt = ref.read(appFormatterProvider);

        // Convert data to table format
        if (data is Map<String, int>) {
          headers = [l10n.category, l10n.amount];
          rows = data.entries
              .map((e) => [e.key, fmt.formatMoney(e.value)])
              .toList();
        } else if (data is Map<DateTime, int>) {
          headers = [l10n.date, l10n.amount];
          rows = data.entries
              .map(
                (e) => [fmt.formatMonthYear(e.key), fmt.formatMoney(e.value)],
              )
              .toList();
        } else if (data is List<MapEntry<String, int>>) {
          headers = [l10n.payee, l10n.amount];
          rows = data.map((e) => [e.key, fmt.formatMoney(e.value)]).toList();
        } else if (data is List<ChartSeries>) {
          headers = [l10n.series, l10n.date, l10n.amount];
          rows = [
            for (final series in data)
              for (final p in series.points)
                [series.name, fmt.formatDate(p.date), fmt.formatMoney(p.value)],
          ];
        } else if (type == ReportType.budgetVsActual &&
            data is List<BudgetVsActualItem>) {
          headers = [l10n.category, l10n.budgeted, l10n.activity];
          rows = data
              .map(
                (e) => [
                  e.categoryName,
                  fmt.formatMoney(e.budgeted),
                  fmt.formatMoney(e.actual),
                ],
              )
              .toList();
        } else {
          // Fallback for types not explicitly handled or complex types
          headers = [l10n.reportPdfDataColumn];
          rows = [
            [data.toString()],
          ];
        }

        await service.generateAndSharePdf(
          title: title,
          headers: headers,
          data: rows,
          filename: '${type.name}_export',
          labels: ReportPdfLabels(
            createdOn: l10n.reportPdfCreatedOn(
              fmt.formatDate(CalendarDate.today()),
            ),
            footer: l10n.reportPdfFooter,
            pageOf: l10n.reportPdfPageOf,
            shareText: l10n.reportShareText(title),
          ),
        );
      } else if (format == ExportFormat.image && imageBytes != null) {
        await service.shareImage(
          imageBytes,
          '${type.name}_chart',
          shareText: l10n.reportShareText(title),
        );
      } else if (format == ExportFormat.csv && csvHeaders != null) {
        // CSV: machine readable amounts (major units, '.' separator).
        final List<List<dynamic>> rows = [csvHeaders];
        if (data is Map<String, int>) {
          rows.addAll(
            data.entries.map(
              (e) => [e.key, CsvLiteral(Money.toDecimalString(e.value))],
            ),
          );
        } else if (data is Map<DateTime, int>) {
          rows.addAll(
            data.entries.map(
              (e) => [
                CsvLiteral(_isoDay(e.key)),
                CsvLiteral(Money.toDecimalString(e.value)),
              ],
            ),
          );
        } else if (data is List<MapEntry<String, int>>) {
          rows.addAll(
            data.map(
              (e) => [e.key, CsvLiteral(Money.toDecimalString(e.value))],
            ),
          );
        } else if (data is List<ChartSeries>) {
          for (final series in data) {
            rows.addAll(
              series.points.map(
                (p) => [
                  series.name,
                  CsvLiteral(_isoDay(p.date)),
                  CsvLiteral(Money.toDecimalString(p.value)),
                ],
              ),
            );
          }
        } else if (data is List<BudgetVsActualItem>) {
          rows.addAll(
            data.map(
              (e) => [
                e.categoryName,
                CsvLiteral(Money.toDecimalString(e.budgeted)),
                CsvLiteral(Money.toDecimalString(e.actual)),
              ],
            ),
          );
        }

        await service.shareCsv(
          rows,
          '${type.name}_export',
          shareText: l10n.reportShareText(title),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        // Share plugin handles the feedback usually, but we can show success
      }
    } catch (e, st) {
      Logger.error('Exporting the report failed', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.exportFailedGeneric)));
      }
    }
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => _ExportDialog(onExport: _exportReport),
    );
  }

  /// The current value of a report [provider], computing it if needed and
  /// keeping it alive until it is read.
  Future<T> _readOnce<T>(ProviderListenable<AsyncValue<T>> provider) async {
    final completer = Completer<T>();
    final subscription = ref.listenManual<AsyncValue<T>>(provider, (_, next) {
      if (!completer.isCompleted && !next.isLoading) {
        next.when(
          data: completer.complete,
          error: completer.completeError,
          loading: () {},
        );
      }
    }, fireImmediately: true);
    try {
      return await completer.future;
    } finally {
      subscription.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateRange = ref.watch(reportDateRangeProvider);
    final fmt = ref.watch(appFormatterProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reports),
        actions: [
          const ReportCategoryFilter(),
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: l10n.export,
            onPressed: _showExportDialog,
          ),
          const ReportDateSelector(),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Date Range Capsule Banner
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.date_range_rounded,
                            size: 16,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${fmt.formatDate(dateRange.start)} - ${fmt.formatDate(dateRange.end)}',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const ReportNotesSection(),
                  const SizedBox(height: 16),

                  // Spending Trends (Compare Months)
                  _ReportCard(
                    title: l10n.spendingTrends,
                    icon: Icons.trending_up_rounded,
                    repaintKey: _chartKeys[ReportType.spendingTrends],
                    child: _SpendingTrendsChart(),
                  ),
                  const SizedBox(height: 16),

                  // Spending by Category (Bar Chart)
                  _ReportCard(
                    title: l10n.spendingByCategory,
                    icon: Icons.bar_chart_rounded,
                    repaintKey: _chartKeys[ReportType.spendingByCategory],
                    child: _SpendingChart(),
                  ),
                  const SizedBox(height: 16),

                  // Category Breakdown (Pie Chart)
                  _ReportCard(
                    title: l10n.categoryBreakdown,
                    icon: Icons.pie_chart_outline_rounded,
                    repaintKey: _chartKeys[ReportType.categoryBreakdown],
                    child: _CategoryPieChart(),
                  ),
                  const SizedBox(height: 16),

                  // Income vs Expense
                  _ReportCard(
                    title: l10n.incomeVsExpense,
                    icon: Icons.swap_vert_rounded,
                    repaintKey: _chartKeys[ReportType.incomeVsExpense],
                    child: _IncomeExpenseChart(),
                  ),
                  const SizedBox(height: 16),

                  // Net Worth
                  _ReportCard(
                    title: l10n.netWorth,
                    icon: Icons.account_balance_wallet_outlined,
                    repaintKey: _chartKeys[ReportType.netWorth],
                    child: _NetWorthChart(),
                  ),
                  const SizedBox(height: 16),

                  // Top Payees
                  _ReportCard(
                    title: l10n.topPayees,
                    icon: Icons.storefront_outlined,
                    repaintKey: _chartKeys[ReportType.topPayees],
                    child: _TopPayeesList(),
                  ),
                  const SizedBox(height: 16),

                  // Budget vs Actual
                  _ReportCard(
                    title: l10n.budgetVsActual,
                    icon: Icons.compare_arrows_rounded,
                    repaintKey: _chartKeys[ReportType.budgetVsActual],
                    child: const BudgetVsActualChart(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
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
      ReportType.budgetVsActual: l10n.budgetVsActual,
    };

    return AlertDialog(
      title: Text(l10n.exportReport),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.selectReportToExport,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ReportType>(
              initialValue: _selectedType,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: ReportType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(reportTitles[type] ?? type.name),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              l10n.exportFormat,
              style: Theme.of(context).textTheme.labelLarge,
            ),
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
            widget.onExport(
              _selectedType,
              _selectedFormat,
              reportTitles[_selectedType]!,
            );
          },
          child: Text(l10n.export),
        ),
      ],
    );
  }
}

/// A modern card framing a report chart and its accessible heading.
class _ReportCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Key? repaintKey;
  final Widget child;

  const _ReportCard({
    required this.title,
    required this.icon,
    this.repaintKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 18, color: scheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(child: _SectionTitle(title)),
              ],
            ),
            const SizedBox(height: 16),
            RepaintBoundary(
              key: repaintKey,
              child: Container(color: scheme.surfaceContainerLow, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

/// A report section heading, announced as a header by screen readers.
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _SpendingTrendsChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendsAsync = ref.watch(spendingTrendsProvider);
    final fmt = ref.watch(appFormatterProvider);

    return trendsAsync.when(
      data: (data) {
        if (data.isEmpty) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Text(AppLocalizations.of(context)!.noTransactions),
            ),
          );
        }

        final sortedKeys = data.keys.toList()..sort();
        final chartData = <String, int>{};

        // If range spans multiple years, show year in label
        final multiYear = sortedKeys.first.year != sortedKeys.last.year;

        for (var date in sortedKeys) {
          final label = multiYear
              ? fmt.formatMonthYearShort(date)
              : fmt.formatMonthShort(date);
          chartData[label] = data[date]!;
        }

        return SimpleBarChart(
          data: chartData,
          barColor: ChartPalette.of(context).secondaryBar,
          labelColor: Theme.of(context).colorScheme.onSurface,
          preserveOrder: true,
        );
      },
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => SizedBox(
        height: 200,
        child: LoadErrorView(error: e, stackTrace: st, compact: true),
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
        barColor: ChartPalette.of(context).bar,
        labelColor: Theme.of(context).colorScheme.onSurface,
      ),
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => SizedBox(
        height: 200,
        child: LoadErrorView(error: e, stackTrace: st, compact: true),
      ),
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
      loading: () => const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => SizedBox(
        height: 300,
        child: LoadErrorView(error: e, stackTrace: st, compact: true),
      ),
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
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => SizedBox(
        height: 200,
        child: LoadErrorView(error: e, stackTrace: st, compact: true),
      ),
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
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => SizedBox(
        height: 200,
        child: LoadErrorView(error: e, stackTrace: st, compact: true),
      ),
    );
  }
}

class _TopPayeesList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payeesAsync = ref.watch(topPayeesProvider);
    final fmt = ref.watch(appFormatterProvider);
    final scheme = Theme.of(context).colorScheme;

    return payeesAsync.when(
      data: (data) {
        if (data.isEmpty) {
          return SizedBox(
            height: 100,
            child: Center(
              child: Text(AppLocalizations.of(context)!.noTransactions),
            ),
          );
        }

        return Column(
          children: [
            for (var i = 0; i < data.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 48,
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 2,
                ),
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  data[i].key,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  fmt.formatMoney(data[i].value),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                dense: true,
              ),
            ],
          ],
        );
      },
      loading: () => const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => SizedBox(
        height: 100,
        child: LoadErrorView(error: e, stackTrace: st, compact: true),
      ),
    );
  }
}
