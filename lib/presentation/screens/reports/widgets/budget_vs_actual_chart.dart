import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/screens/reports/providers/report_providers.dart';

class BudgetVsActualChart extends ConsumerWidget {
  const BudgetVsActualChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(budgetVsActualProvider);
    final currencyFormat = NumberFormat.simpleCurrency(decimalDigits: 0);
    final l10n = AppLocalizations.of(context)!;

    return dataAsync.when(
      data: (items) {
        if (items.isEmpty) {
           return SizedBox(height: 100, child: Center(child: Text(l10n.noTransactions)));
        }

        // Take top 10 for chart clarity, maybe
        final displayItems = items.take(10).toList();

        return Column(
          children: displayItems.map((item) {
             // Usually global max is better for comparison across categories.
             // But for budget vs actual, often we just want to see the relation between the two per category.
             // Let's use global max of the displayed items to keep scale consistent.

             final globalMax = displayItems.fold(0.0, (prev, curr) {
               final m = curr.budgeted > curr.actual ? curr.budgeted : curr.actual;
               return m > prev ? m : prev;
             });
             final safeGlobalMax = globalMax == 0 ? 1.0 : globalMax;

             return Padding(
               padding: const EdgeInsets.symmetric(vertical: 8.0),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(item.categoryName, style: Theme.of(context).textTheme.bodyMedium),
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
                                   flex: (item.budgeted / safeGlobalMax * 100).toInt(),
                                   child: Container(
                                     height: 8,
                                     color: AppColors.primaryLight,
                                     margin: const EdgeInsets.only(right: 4),
                                   ),
                                 ),
                                 Expanded(
                                    flex: 100 - (item.budgeted / safeGlobalMax * 100).toInt(),
                                    child: const SizedBox(),
                                 ),
                                 SizedBox(
                                   width: 60,
                                   child: Text(
                                     currencyFormat.format(item.budgeted),
                                     style: const TextStyle(fontSize: 10),
                                     textAlign: TextAlign.right,
                                   ),
                                 )
                               ],
                             ),
                             const SizedBox(height: 2),
                             // Actual Bar
                             Row(
                               children: [
                                 Expanded(
                                   flex: (item.actual / safeGlobalMax * 100).toInt(),
                                   child: Container(
                                     height: 8,
                                     color: AppColors.errorLight,
                                     margin: const EdgeInsets.only(right: 4),
                                   ),
                                 ),
                                 Expanded(
                                    flex: 100 - (item.actual / safeGlobalMax * 100).toInt(),
                                    child: const SizedBox(),
                                 ),
                                 SizedBox(
                                   width: 60,
                                   child: Text(
                                     currencyFormat.format(item.actual),
                                     style: const TextStyle(fontSize: 10),
                                     textAlign: TextAlign.right,
                                   ),
                                 )
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
        );
      },
      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      error: (e, st) => SizedBox(height: 200, child: Center(child: Text('${l10n.error}: $e'))),
    );
  }
}
