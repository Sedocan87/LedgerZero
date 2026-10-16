import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/screens/reports/providers/report_providers.dart';

class ReportDateSelector extends ConsumerWidget {
  const ReportDateSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return IconButton(
      icon: const Icon(Icons.date_range),
      tooltip: l10n.dateRange,
      onPressed: () {
        _showDateRangeOptions(context, ref, l10n);
      },
    );
  }

  void _showDateRangeOptions(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    /// Sets the report range to the inclusive calendar days [start]..[end].
    void select(BuildContext sheetContext, DateTime start, DateTime end) {
      ref.read(reportDateRangeProvider.notifier).state = DateTimeRange(
        start: CalendarDate.normalize(start),
        end: CalendarDate.normalize(end),
      );
      Navigator.pop(sheetContext);
    }

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        final today = CalendarDate.today();
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(l10n.thisMonth),
                onTap: () => select(
                  sheetContext,
                  CalendarDate.startOfMonthUtc(today),
                  DateTime.utc(today.year, today.month + 1, 0),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(l10n.lastMonth),
                onTap: () => select(
                  sheetContext,
                  DateTime.utc(today.year, today.month - 1, 1),
                  DateTime.utc(today.year, today.month, 0),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: Text(l10n.last3Months),
                onTap: () => select(
                  sheetContext,
                  DateTime.utc(today.year, today.month, today.day - 90),
                  today,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: Text(l10n.last6Months),
                onTap: () => select(
                  sheetContext,
                  DateTime.utc(today.year, today.month, today.day - 180),
                  today,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_view_month),
                title: Text(l10n.thisYear),
                onTap: () => select(
                  sheetContext,
                  DateTime.utc(today.year, 1, 1),
                  DateTime.utc(today.year, 12, 31),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(l10n.lastYear),
                onTap: () => select(
                  sheetContext,
                  DateTime.utc(today.year - 1, 1, 1),
                  DateTime.utc(today.year - 1, 12, 31),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit_calendar),
                title: Text(l10n.custom),
                onTap: () async {
                  Navigator.pop(sheetContext); // Close sheet first
                  final current = ref.read(reportDateRangeProvider);
                  final newRange = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialDateRange: DateTimeRange(
                      start: CalendarDate.toLocalDay(current.start),
                      end: CalendarDate.toLocalDay(current.end),
                    ),
                  );
                  if (newRange != null && context.mounted) {
                    ref
                        .read(reportDateRangeProvider.notifier)
                        .state = DateTimeRange(
                      start: CalendarDate.fromLocalPick(newRange.start),
                      end: CalendarDate.fromLocalPick(newRange.end),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
