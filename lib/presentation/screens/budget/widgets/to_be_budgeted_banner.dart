import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';

class ToBeBudgetedBanner extends ConsumerWidget {
  const ToBeBudgetedBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tbbAsync = ref.watch(tbbProvider);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              AppLocalizations.of(context)!.toBeBudgeted,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 8),
            tbbAsync.when(
              data: (tbb) => Text(
                NumberFormat.simpleCurrency(decimalDigits: 2).format(tbb),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: tbb >= 0 ? Colors.green.shade700 : Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              loading: () => const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (err, stack) => Text('Error', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ],
        ),
      ),
    );
  }
}
