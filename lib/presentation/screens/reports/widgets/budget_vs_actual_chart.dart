import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/reports/providers/report_providers.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_palette.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';

/// Budgeted and actual amount per category as paired bars.
///
/// Screen readers get one summary label with both amounts per category.
class BudgetVsActualChart extends ConsumerWidget {
  const BudgetVsActualChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(budgetVsActualProvider);
    final fmt = ref.watch(appFormatterProvider);
    final l10n = AppLocalizations.of(context)!;
    final palette = ChartPalette.of(context);

    return dataAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return SizedBox(
            height: 100,
            child: Center(child: Text(l10n.noTransactions)),
          );
        }

        // Take top 10 for chart clarity, maybe
        final displayItems = items.take(10).toList();

        // Use the global max of the displayed items to keep the scale
        // consistent across categories (minor units).
        var globalMax = 0;
        for (final item in displayItems) {
          final m = item.budgeted > item.actual ? item.budgeted : item.actual;
          if (m > globalMax) {
            globalMax = m;
          }
        }
        final safeGlobalMax = globalMax == 0 ? 1 : globalMax;

        /// Bar length in percent of the widest bar.
        int percentOf(int amount) =>
            (amount * 100 ~/ safeGlobalMax).clamp(0, 100);

        final summary = l10n.chartBudgetVsActualSemantics(
          displayItems
              .map(
                (item) => l10n.chartBudgetVsActualItemSemantics(
                  item.categoryName,
                  fmt.formatMoney(item.budgeted),
                  fmt.formatMoney(item.actual),
                ),
              )
              .join(', '),
        );

        return Semantics(
          label: summary,
          excludeSemantics: true,
          child: Column(
            children: displayItems.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.categoryName,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              // Budget Bar
                              Row(
                                children: [
                                  Expanded(
                                    flex: percentOf(item.budgeted),
                                    child: Container(
                                      height: 8,
                                      color: palette.budgeted,
                                      margin: const EdgeInsets.only(right: 4),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 100 - percentOf(item.budgeted),
                                    child: const SizedBox(),
                                  ),
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      fmt.formatMoneyCompact(item.budgeted),
                                      style: const TextStyle(fontSize: 10),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              // Actual Bar
                              Row(
                                children: [
                                  Expanded(
                                    flex: percentOf(item.actual),
                                    child: Container(
                                      height: 8,
                                      color: palette.spent,
                                      margin: const EdgeInsets.only(right: 4),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 100 - percentOf(item.actual),
                                    child: const SizedBox(),
                                  ),
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      fmt.formatMoneyCompact(item.actual),
                                      style: const TextStyle(fontSize: 10),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
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
