import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';

class ToBeBudgetedBanner extends ConsumerWidget {
  const ToBeBudgetedBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tbbAsync = ref.watch(tbbProvider);
    final currency = ref.watch(settingsProvider).currency;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context)!.toBeBudgeted,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: AppLocalizations.of(context)!.tbbTooltip,
                  triggerMode: TooltipTriggerMode.tap,
                  child: Icon(
                    Icons.help_outline,
                    size: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            tbbAsync.when(
              data: (tbb) {
                final textWidget = Text(
                  NumberFormat.simpleCurrency(
                    decimalDigits: 2,
                    name: currency,
                  ).format(tbb),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: tbb >= 0
                        ? Colors.green.shade700
                        : Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                );

                if (tbb <= 0) {
                  return textWidget;
                }

                return LongPressDraggable<double>(
                  data: tbb,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        NumberFormat.simpleCurrency(
                          decimalDigits: 2,
                          name: currency,
                        ).format(tbb),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(opacity: 0.5, child: textWidget),
                  child: textWidget,
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
