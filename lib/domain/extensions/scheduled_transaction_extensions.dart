import 'dart:math' as math;

import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';

/// Calendar arithmetic for recurring schedules.
///
/// All dates are calendar days stored as UTC midnight (see [CalendarDate]).
/// Inputs are normalised first (a local DateTime keeps its own calendar day)
/// and every step is computed with `DateTime.utc(y, m, d + n)`, so daylight
/// saving transitions of the host time zone can never shift a day.
abstract final class RecurrenceMath {
  /// Number of days of [month] in [year] (month may overflow, e.g. 13).
  static int daysInMonth(int year, int month) =>
      DateTime.utc(year, month + 1, 0).day;

  /// The occurrence [interval] periods of [frequency] after [from].
  ///
  /// Monthly and yearly steps aim for [anchorDay] (default: the day of
  /// [from]) and clamp it to the length of the target month, so an anchor of
  /// 31 yields Jan 31 -> Feb 29 -> Mar 31 -> Apr 30, and a yearly Feb 29
  /// yields Feb 28 in common years and Feb 29 again in leap years.
  static DateTime step(
    DateTime from,
    RecurrenceFrequency frequency,
    int interval, {
    int? anchorDay,
  }) {
    final d = CalendarDate.normalize(from);
    final n = math.max(1, interval);
    switch (frequency) {
      case RecurrenceFrequency.daily:
        return DateTime.utc(d.year, d.month, d.day + n);
      case RecurrenceFrequency.weekly:
        return DateTime.utc(d.year, d.month, d.day + 7 * n);
      case RecurrenceFrequency.monthly:
        return _onAnchor(d.year, d.month + n, anchorDay ?? d.day);
      case RecurrenceFrequency.yearly:
        return _onAnchor(d.year + n, d.month, anchorDay ?? d.day);
    }
  }

  static DateTime _onAnchor(int year, int month, int anchorDay) {
    // Normalise an overflowing month (e.g. 14 -> February next year).
    final first = DateTime.utc(year, month, 1);
    final day = math.min(
      anchorDay.clamp(1, 31),
      daysInMonth(first.year, first.month),
    );
    return DateTime.utc(first.year, first.month, day);
  }
}

extension ScheduledTransactionExtensions on ScheduledTransaction {
  /// The occurrence after [nextDate] according to [frequency] (default
  /// monthly), [interval] (default 1) and [anchorDay], as a calendar day
  /// (UTC midnight). Returns `null` if [nextDate] is null or the result is
  /// after [endDate].
  DateTime? calculateNextOccurrenceDate() {
    final current = nextDate;
    if (current == null) {
      return null;
    }
    final next = RecurrenceMath.step(
      current,
      frequency ?? RecurrenceFrequency.monthly,
      interval ?? 1,
      anchorDay: anchorDay,
    );
    if (endDate != null && next.isAfter(CalendarDate.normalize(endDate!))) {
      return null;
    }
    return next;
  }

  /// Whether the schedule has no further occurrence.
  bool get isFinished => nextDate == null;

  /// The schedule after its current occurrence ([nextDate]) has been
  /// materialised or skipped. Shared by catch-up processing and "skip".
  ///
  /// * [nextDate] moves to the next occurrence (calendar day, UTC midnight).
  /// * A counted schedule ([occurrenceCount] != null) decrements its count.
  /// * The schedule finishes (`nextDate == null`) when the count reaches 0
  ///   or the next occurrence would be after [endDate]; a counted schedule
  ///   then has `occurrenceCount == 0`.
  /// * Monthly and yearly schedules pin [anchorDay] (to the current day if
  ///   it was unset) so a clamped month end does not lose the original day.
  ///
  /// A finished schedule is returned unchanged.
  ScheduledTransaction advanced() {
    final current = nextDate;
    if (current == null) {
      return this;
    }
    final remaining = occurrenceCount == null
        ? null
        : math.max(0, occurrenceCount! - 1);
    final next = calculateNextOccurrenceDate();
    if (next == null || remaining == 0) {
      return copyWith(clearNextDate: true, occurrenceCount: remaining);
    }
    final freq = frequency ?? RecurrenceFrequency.monthly;
    final pinsAnchor =
        freq == RecurrenceFrequency.monthly ||
        freq == RecurrenceFrequency.yearly;
    return copyWith(
      nextDate: next,
      occurrenceCount: remaining,
      anchorDay: pinsAnchor ? (anchorDay ?? current.day) : null,
    );
  }
}
