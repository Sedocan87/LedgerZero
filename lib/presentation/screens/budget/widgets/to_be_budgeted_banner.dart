import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/widgets/common/amount_text.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';

class ToBeBudgetedBanner extends ConsumerWidget {
  const ToBeBudgetedBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tbbAsync = ref.watch(
      tbbProvider(ref.watch(selectedBudgetMonthProvider)),
    );
    final fmt = ref.watch(appFormatterProvider);

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
                  // 16 px icon, 48 x 48 tap target.
                  child: SizedBox.square(
                    dimension: kMinInteractiveDimension,
                    child: Icon(
                      Icons.help_outline,
                      size: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            tbbAsync.when(
              data: (tbb) {
                final formatted = fmt.formatMoney(tbb);
                final textWidget = AmountText(
                  tbb,
                  amountContext: AmountContext.toBeBudgeted,
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

                return LongPressDraggable<int>(
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
                        formatted,
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
              error: (err, stack) =>
                  LoadErrorView(error: err, stackTrace: stack, compact: true),
            ),
          ],
        ),
      ),
    );
  }
}
