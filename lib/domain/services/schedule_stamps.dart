import 'package:ledger_zero/core/time/calendar_date.dart';

/// Sync timestamps (`updated_at`) of what the scheduled-transaction
/// catch-up writes.
///
/// The catch-up runs on every phone of a household, and each run writes
/// the same occurrences (deterministic ids) and the same advance of the
/// schedule. Stamped with the current time, the copy of the phone that
/// runs last would be the newest version of the row and replace what the
/// partner did with it in the meantime (an edited or deleted occurrence, an
/// edited or skipped schedule). So these writes carry a timestamp that
/// does not depend on when or where the catch-up ran and that is older
/// than anything a person does with the row afterwards, the way the
/// new-month fill does (`BudgetingService.automaticFillStamp`).
abstract final class ScheduleStamps {
  /// The timestamp of the generated occurrence dated [date]: 00:00 UTC of
  /// the day before. An occurrence is booked on or after its calendar day,
  /// and that day begins nowhere on earth before 10:00 UTC of the day
  /// before (UTC+14), so every edit of the booked row is newer; and two
  /// phones generating it agree.
  static DateTime occurrence(DateTime date) {
    final day = CalendarDate.normalize(date);
    return DateTime.utc(day.year, day.month, day.day - 1);
  }

  /// The timestamp of a schedule row after the catch-up advanced it over
  /// [occurrences] due occurrences (or finished it), given the row's
  /// timestamp [previous] before: one millisecond later per occurrence.
  ///
  /// * It only moves forward, so an older version can never come back.
  /// * Two phones advancing from the same version by the same number of
  ///   occurrences write the same timestamp (and the same content); the
  ///   phone that advanced further is newer.
  /// * An edit or a skip by a person carries the time it was made, which
  ///   is later than a few milliseconds after the version it started
  ///   from, and wins.
  static DateTime catchUp(DateTime previous, int occurrences) => previous
      .toUtc()
      .add(Duration(milliseconds: occurrences < 1 ? 1 : occurrences));
}
