import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/constants/app_icons.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/extensions/scheduled_transaction_extensions.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';

enum EndCondition { never, onDate, afterOccurrences }

class RecurrenceSelector extends ConsumerStatefulWidget {
  final RecurrenceFrequency frequency;
  final ValueChanged<RecurrenceFrequency> onFrequencyChanged;
  final int interval;
  final ValueChanged<int> onIntervalChanged;

  /// End date as a calendar day (UTC midnight); picked dates are reported
  /// in the same form.
  final DateTime? endDate;
  final ValueChanged<DateTime?> onEndDateChanged;
  final int? occurrenceCount;
  final ValueChanged<int?> onOccurrenceCountChanged;

  /// Next occurrence (calendar day); needed for date picker constraints.
  final DateTime nextDate;

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

  @override
  ConsumerState<RecurrenceSelector> createState() => _RecurrenceSelectorState();
}

class _RecurrenceSelectorState extends ConsumerState<RecurrenceSelector> {
  // The text fields own their text so typing never rebuilds them (which
  // would drop focus); external value changes are copied in.
  late final TextEditingController _intervalController = TextEditingController(
    text: widget.interval.toString(),
  );
  late final TextEditingController _occurrencesController =
      TextEditingController(text: (widget.occurrenceCount ?? 10).toString());

  RecurrenceFrequency get frequency => widget.frequency;
  ValueChanged<RecurrenceFrequency> get onFrequencyChanged =>
      widget.onFrequencyChanged;
  ValueChanged<int> get onIntervalChanged => widget.onIntervalChanged;
  DateTime? get endDate => widget.endDate;
  ValueChanged<DateTime?> get onEndDateChanged => widget.onEndDateChanged;
  int? get occurrenceCount => widget.occurrenceCount;
  ValueChanged<int?> get onOccurrenceCountChanged =>
      widget.onOccurrenceCountChanged;
  DateTime get nextDate => widget.nextDate;

  @override
  void didUpdateWidget(covariant RecurrenceSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(_intervalController, widget.interval);
    if (widget.occurrenceCount != null) {
      _sync(_occurrencesController, widget.occurrenceCount!);
    }
  }

  void _sync(TextEditingController controller, int value) {
    if (int.tryParse(controller.text) == value) {
      return;
    }
    // Changing the controller notifies the enclosing Form, which must not
    // happen during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && int.tryParse(controller.text) != value) {
        controller.text = value.toString();
      }
    });
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _occurrencesController.dispose();
    super.dispose();
  }

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
    final fmt = ref.watch(appFormatterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.frequency, style: Theme.of(context).textTheme.titleSmall),
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
            Expanded(child: Text(l10n.repeatEvery)),
            SizedBox(
              width: 80,
              child: TextFormField(
                controller: _intervalController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
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
              child: Text(
                _getFrequencyUnitLabel(l10n, frequency, widget.interval),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(l10n.end, style: Theme.of(context).textTheme.titleSmall),
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
                  // Default to one calendar month after the next date.
                  onEndDateChanged(
                    RecurrenceMath.step(
                      nextDate,
                      RecurrenceFrequency.monthly,
                      1,
                    ),
                  );
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
                initialDate: CalendarDate.toLocalDay(endDate ?? nextDate),
                firstDate: CalendarDate.toLocalDay(nextDate),
                lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
              );
              if (date != null && mounted) {
                onEndDateChanged(CalendarDate.fromLocalPick(date));
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.endDate,
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(AppIcons.calendar),
              ),
              child: Text(endDate != null ? fmt.formatDate(endDate!) : ''),
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
                  controller: _occurrencesController,
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

  String _getFrequencyUnitLabel(
    AppLocalizations l10n,
    RecurrenceFrequency frequency,
    int count,
  ) {
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
