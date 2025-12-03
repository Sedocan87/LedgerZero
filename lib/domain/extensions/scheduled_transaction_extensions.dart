import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';

extension ScheduledTransactionExtensions on ScheduledTransaction {
  /// Calculates the next occurrence date based on the current [nextDate], [frequency], and [interval].
  /// Returns `null` if [nextDate] is null or if the calculated date is after [endDate].
  DateTime? calculateNextOccurrenceDate() {
    if (nextDate == null) {
      return null;
    }

    final currentNextDate = nextDate!;
    final recurrenceInterval = interval ?? 1;
    final recurrenceFrequency = frequency ?? RecurrenceFrequency.monthly;

    DateTime newDate;
    switch (recurrenceFrequency) {
      case RecurrenceFrequency.daily:
        newDate = currentNextDate.add(Duration(days: recurrenceInterval));
        break;
      case RecurrenceFrequency.weekly:
        newDate = currentNextDate.add(Duration(days: recurrenceInterval * 7));
        break;
      case RecurrenceFrequency.monthly:
        if (currentNextDate.isUtc) {
          newDate = DateTime.utc(
            currentNextDate.year,
            currentNextDate.month + recurrenceInterval,
            currentNextDate.day,
            currentNextDate.hour,
            currentNextDate.minute,
          );
        } else {
          newDate = DateTime(
            currentNextDate.year,
            currentNextDate.month + recurrenceInterval,
            currentNextDate.day,
            currentNextDate.hour,
            currentNextDate.minute,
          );
        }

        // Handle month overflow (e.g., Jan 31 + 1 month = Feb 31 -> Mar 3)
        // We want to clamp to the last day of the expected month.
        final expectedMonth = (currentNextDate.month + recurrenceInterval - 1) % 12 + 1;
        final expectedYear = currentNextDate.year + (currentNextDate.month + recurrenceInterval - 1) ~/ 12;

        if (newDate.month != expectedMonth) {
          // We overshot (e.g., Feb 31 -> Mar 3), so go back to last day of previous month (which is the expected month)
          if (currentNextDate.isUtc) {
            newDate = DateTime.utc(expectedYear, expectedMonth + 1, 0, currentNextDate.hour, currentNextDate.minute);
          } else {
            newDate = DateTime(expectedYear, expectedMonth + 1, 0, currentNextDate.hour, currentNextDate.minute);
          }
        }
        break;
      case RecurrenceFrequency.yearly:
        if (currentNextDate.isUtc) {
          newDate = DateTime.utc(
            currentNextDate.year + recurrenceInterval,
            currentNextDate.month,
            currentNextDate.day,
            currentNextDate.hour,
            currentNextDate.minute,
          );
        } else {
          newDate = DateTime(
            currentNextDate.year + recurrenceInterval,
            currentNextDate.month,
            currentNextDate.day,
            currentNextDate.hour,
            currentNextDate.minute,
          );
        }
        // Handle leap year (Feb 29 + 1 year -> Feb 29 non-leap = Mar 1).
        // If originally Feb 29, and new year is not leap year, Dart DateTime might make it Mar 1.
        // Usually we prefer Feb 28.
        // Dart: DateTime(2023, 2, 29) -> Mar 1, 2023.
        if (currentNextDate.month == 2 && currentNextDate.day == 29 && newDate.month == 3) {
          if (currentNextDate.isUtc) {
            newDate = DateTime.utc(newDate.year, 2, 28, newDate.hour, newDate.minute);
          } else {
            newDate = DateTime(newDate.year, 2, 28, newDate.hour, newDate.minute);
          }
        }
        break;
    }

    if (endDate != null && newDate.isAfter(endDate!)) {
      return null;
    }

    return newDate;
  }
}
