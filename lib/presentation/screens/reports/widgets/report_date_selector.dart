import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(l10n.thisMonth),
                onTap: () {
                  final now = DateTime.now();
                  final start = DateTime(now.year, now.month, 1);
                  final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59).subtract(const Duration(milliseconds: 1));
                  ref.read(reportDateRangeProvider.notifier).state =
                      DateTimeRange(start: start, end: end);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(l10n.lastMonth),
                onTap: () {
                  final now = DateTime.now();
                  final start = DateTime(now.year, now.month - 1, 1);
                  final end = DateTime(now.year, now.month, 0, 23, 59, 59);
                  ref.read(reportDateRangeProvider.notifier).state =
                      DateTimeRange(start: start, end: end);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: Text(l10n.last3Months),
                onTap: () {
                  final now = DateTime.now();
                  final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
                  final start = now.subtract(const Duration(days: 90));
                  ref.read(reportDateRangeProvider.notifier).state =
                      DateTimeRange(start: start, end: end);
                  Navigator.pop(context);
                },
              ),
               ListTile(
                leading: const Icon(Icons.date_range),
                title: Text(l10n.last6Months),
                onTap: () {
                  final now = DateTime.now();
                  final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
                  final start = now.subtract(const Duration(days: 180));
                  ref.read(reportDateRangeProvider.notifier).state =
                      DateTimeRange(start: start, end: end);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_view_month),
                title: Text(l10n.thisYear),
                onTap: () {
                  final now = DateTime.now();
                  final start = DateTime(now.year, 1, 1);
                  final end = DateTime(now.year, 12, 31, 23, 59, 59);
                  ref.read(reportDateRangeProvider.notifier).state =
                      DateTimeRange(start: start, end: end);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(l10n.lastYear),
                onTap: () {
                  final now = DateTime.now();
                  final start = DateTime(now.year - 1, 1, 1);
                  final end = DateTime(now.year - 1, 12, 31, 23, 59, 59);
                  ref.read(reportDateRangeProvider.notifier).state =
                      DateTimeRange(start: start, end: end);
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit_calendar),
                title: Text(l10n.custom),
                onTap: () async {
                  Navigator.pop(context); // Close sheet first
                  final current = ref.read(reportDateRangeProvider);
                  final newRange = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialDateRange: current,
                  );
                  if (newRange != null) {
                    ref.read(reportDateRangeProvider.notifier).state = newRange;
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
