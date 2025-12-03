import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/core/constants/app_icons.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

enum EndCondition {
  never,
  onDate,
  afterOccurrences,
}

class RecurrenceSelector extends StatelessWidget {
  final RecurrenceFrequency frequency;
  final ValueChanged<RecurrenceFrequency> onFrequencyChanged;
  final int interval;
  final ValueChanged<int> onIntervalChanged;
  final DateTime? endDate;
  final ValueChanged<DateTime?> onEndDateChanged;
  final int? occurrenceCount;
  final ValueChanged<int?> onOccurrenceCountChanged;
  final DateTime nextDate; // Needed for date picker constraints

  const RecurrenceSelector({
    super.key,
    required this.frequency,
    required this.onFrequencyChanged,
    required this.interval,
    required this.onIntervalChanged,
    required this.endDate,
    required this.onEndDateChanged,
    required this.occurrenceCount,
    required this.onOccurrenceCountChanged,
    required this.nextDate,
  });

  EndCondition get _currentEndCondition {
    if (occurrenceCount != null) {
      return EndCondition.afterOccurrences;
    }
    if (endDate != null) {
      return EndCondition.onDate;
    }
    return EndCondition.never;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.frequency,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<RecurrenceFrequency>(
            segments: [
              ButtonSegment(
                value: RecurrenceFrequency.daily,
                label: Text(l10n.daily),
              ),
              ButtonSegment(
                value: RecurrenceFrequency.weekly,
                label: Text(l10n.weekly),
              ),
              ButtonSegment(
                value: RecurrenceFrequency.monthly,
                label: Text(l10n.monthly),
              ),
              ButtonSegment(
                value: RecurrenceFrequency.yearly,
                label: Text(l10n.yearly),
              ),
            ],
            selected: {frequency},
            onSelectionChanged: (Set<RecurrenceFrequency> newSelection) {
              onFrequencyChanged(newSelection.first);
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(l10n.repeatEvery),
            ),
            SizedBox(
              width: 80,
              child: TextFormField(
                key: ValueKey('interval_$interval'),
                initialValue: interval.toString(),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final newInterval = int.tryParse(value);
                  if (newInterval != null && newInterval > 0) {
                    onIntervalChanged(newInterval);
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(_getFrequencyUnitLabel(l10n, frequency, interval)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          l10n.end,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<EndCondition>(
          key: ValueKey(_currentEndCondition),
          initialValue: _currentEndCondition,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: EndCondition.never,
              child: Text(l10n.never),
            ),
            DropdownMenuItem(
              value: EndCondition.onDate,
              child: Text(l10n.onDate),
            ),
            DropdownMenuItem(
              value: EndCondition.afterOccurrences,
              child: Text(l10n.afterOccurrences),
            ),
          ],
          onChanged: (EndCondition? value) {
            if (value == null) {
              return;
            }
            switch (value) {
              case EndCondition.never:
                onEndDateChanged(null);
                onOccurrenceCountChanged(null);
                break;
              case EndCondition.onDate:
                onOccurrenceCountChanged(null);
                if (endDate == null) {
                  // Default to nextDate + 1 month roughly
                  onEndDateChanged(nextDate.add(const Duration(days: 30)));
                }
                break;
              case EndCondition.afterOccurrences:
                onEndDateChanged(null);
                if (occurrenceCount == null) {
                  onOccurrenceCountChanged(10);
                }
                break;
            }
          },
        ),
        if (_currentEndCondition == EndCondition.onDate) ...[
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: endDate ?? nextDate,
                firstDate: nextDate,
                lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
              );
              if (date != null) {
                onEndDateChanged(date);
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.endDate,
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(AppIcons.calendar),
              ),
              child: Text(
                endDate != null ? DateFormat.yMMMd().format(endDate!) : '',
              ),
            ),
          ),
        ],
        if (_currentEndCondition == EndCondition.afterOccurrences) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 100,
                child: TextFormField(
                  key: ValueKey('occurrences_$occurrenceCount'),
                  initialValue: (occurrenceCount ?? 10).toString(),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l10n.occurrences,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    final val = int.tryParse(value);
                    if (val != null && val > 0) {
                      onOccurrenceCountChanged(val);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _getFrequencyUnitLabel(AppLocalizations l10n, RecurrenceFrequency frequency, int count) {
    switch (frequency) {
      case RecurrenceFrequency.daily:
        return l10n.unitDays(count);
      case RecurrenceFrequency.weekly:
        return l10n.unitWeeks(count);
      case RecurrenceFrequency.monthly:
        return l10n.unitMonths(count);
      case RecurrenceFrequency.yearly:
        return l10n.unitYears(count);
    }
  }
}
