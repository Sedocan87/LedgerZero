import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';

class MonthSelector extends ConsumerWidget {
  const MonthSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedBudgetMonthProvider);
    final fmt = ref.watch(appFormatterProvider);
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: l10n.previousMonth,
          onPressed: () {
            ref.read(selectedBudgetMonthProvider.notifier).state = DateTime.utc(
              selectedMonth.year,
              selectedMonth.month - 1,
            );
          },
        ),
        // Long month names ("September 2026") shrink instead of
        // overflowing on narrow phones.
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                fmt.formatMonthYear(selectedMonth),
                maxLines: 1,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: l10n.nextMonth,
          onPressed: () {
            ref.read(selectedBudgetMonthProvider.notifier).state = DateTime.utc(
              selectedMonth.year,
              selectedMonth.month + 1,
            );
          },
        ),
      ],
    );
  }
}
