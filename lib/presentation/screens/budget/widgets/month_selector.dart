import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';

/// The Budget tab's month, shown as the app bar title: previous month,
/// the month (tap for the month picker), next month.
class MonthSelector extends ConsumerWidget {
  const MonthSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedBudgetMonthProvider);
    void select(DateTime month) =>
        ref.read(selectedBudgetMonthProvider.notifier).state = month;
    return MonthSwitcher(
      month: selectedMonth,
      // A little under the usual title size: with the chevrons and the
      // actions, "September 2026" fits a 392 dp phone without shrinking much.
      style: Theme.of(
        context,
      ).appBarTheme.titleTextStyle?.copyWith(fontSize: 18),
      onChanged: select,
      onPick: () async {
        final picked = await showMonthPicker(context, initial: selectedMonth);
        if (picked != null) {
          select(picked);
        }
      },
    );
  }
}

/// `‹ November 2026 ▾ ›` without a frame: the chevrons step one month, the
/// month opens a picker ([onPick]). [canGoNext] false disables the next
/// chevron (Home does not go past the current month). A long month name
/// shrinks instead of overflowing a narrow app bar.
class MonthSwitcher extends ConsumerWidget {
  const MonthSwitcher({
    super.key,
    required this.month,
    required this.onChanged,
    required this.onPick,
    this.canGoNext = true,
    this.style,
  });

  /// First day of the month shown (UTC).
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  final VoidCallback onPick;
  final bool canGoNext;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(appFormatterProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final textStyle = (style ?? theme.textTheme.titleMedium)?.copyWith(
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurface,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: l10n.previousMonth,
          onPressed: () => onChanged(DateTime.utc(month.year, month.month - 1)),
        ),
        Flexible(
          child: InkWell(
            key: const Key('month.pick'),
            onTap: onPick,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kMinInteractiveDimension,
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fmt.formatMonthYear(month),
                        maxLines: 1,
                        style: textStyle,
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: l10n.nextMonth,
          onPressed: canGoNext
              ? () => onChanged(DateTime.utc(month.year, month.month + 1))
              : null,
        ),
      ],
    );
  }
}

/// The month picker: the date picker opened on its year list; the month of
/// the picked day is returned (first day, UTC), or `null` when cancelled.
Future<DateTime?> showMonthPicker(
  BuildContext context, {
  required DateTime initial,
  DateTime? lastDate,
}) async {
  final last = lastDate ?? DateTime(DateTime.now().year + 10, 12, 31);
  var initialDate = CalendarDate.toLocalDay(initial);
  if (initialDate.isAfter(last)) {
    initialDate = last;
  }
  final picked = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(2000),
    lastDate: last,
    initialDatePickerMode: DatePickerMode.year,
  );
  return picked == null ? null : DateTime.utc(picked.year, picked.month);
}
