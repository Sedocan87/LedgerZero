import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

final tbbProvider = FutureProvider.autoDispose.family<double, DateTime>((
  ref,
  month,
) {
  final budgetingService = ref.watch(budgetingServiceProvider);
  return budgetingService.calculateTBB(month);
});

class ToBeBudgetedWidget extends ConsumerWidget {
  const ToBeBudgetedWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month); // Stable month start
    final tbbAsync = ref.watch(tbbProvider(currentMonth));
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              l10n.toBeBudgeted,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            tbbAsync.when(
              data: (tbb) {
                final currencyFormat = NumberFormat.simpleCurrency();
                final color = tbb >= 0 ? Colors.green : Colors.red;
                return Text(
                  currencyFormat.format(tbb),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
              loading: () => const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (err, stack) => Text(
                'Error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
