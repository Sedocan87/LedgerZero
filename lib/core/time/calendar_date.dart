/// Date helpers implementing the storage rule for dates (decision D9):
///
/// * Every DateTime written to the database or a sync payload is UTC.
/// * Date-only values (transaction date, scheduled dates, goal dates) are a
///   calendar day stored as UTC midnight of the day the user picked, and are
///   displayed as that calendar day (read the `year`/`month`/`day` fields,
///   never call `toLocal()` on them).
/// * Month and range queries use half-open UTC intervals
///   `[startOfMonthUtc, endOfMonthUtc)`.
abstract final class CalendarDate {
  /// UTC midnight of the calendar day shown by [picked] (its own
  /// year/month/day fields, whether it is local or UTC).
  static DateTime fromLocalPick(DateTime picked) =>
      DateTime.utc(picked.year, picked.month, picked.day);

  /// Normalises any DateTime to the stored calendar-day form. Alias of
  /// [fromLocalPick] that reads better at storage boundaries.
  static DateTime normalize(DateTime value) => fromLocalPick(value);

  /// The user's current calendar day as UTC midnight.
  static DateTime today({DateTime? now}) =>
      fromLocalPick((now ?? DateTime.now()).toLocal());

  /// A local DateTime for the calendar day of [stored], for date pickers
  /// and comparisons with local "now".
  static DateTime toLocalDay(DateTime stored) =>
      DateTime(stored.year, stored.month, stored.day);

  /// First day of [month]'s month at UTC midnight (inclusive bound).
  static DateTime startOfMonthUtc(DateTime month) =>
      DateTime.utc(month.year, month.month, 1);

  /// First day of the month after [month] at UTC midnight (exclusive
  /// bound). Use as `date < endOfMonthUtc(month)`.
  static DateTime endOfMonthUtc(DateTime month) =>
      DateTime.utc(month.year, month.month + 1, 1);

  /// UTC midnight of the day after [day] (exclusive bound for an inclusive
  /// calendar-day end such as a filter's "to" date).
  static DateTime endOfDayUtc(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day + 1);

  /// First day of the year of [year] at UTC midnight.
  static DateTime startOfYearUtc(int year) => DateTime.utc(year, 1, 1);

  /// First day of the following year at UTC midnight (exclusive bound).
  static DateTime endOfYearUtc(int year) => DateTime.utc(year + 1, 1, 1);

  /// The earliest instant used for "all history" queries.
  static final DateTime beginningOfTime = DateTime.utc(1970, 1, 1);

  /// `yyyy-MM` key of [date]'s calendar month.
  static String monthKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

  /// Parses a `yyyy-MM` key into the first day of that month (UTC).
  static DateTime parseMonthKey(String key) {
    final parts = key.split('-');
    return DateTime.utc(int.parse(parts[0]), int.parse(parts[1]), 1);
  }

  /// Whether [a] and [b] fall on the same calendar day (by their fields).
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Convenience accessors for the storage rules in [CalendarDate].
extension CalendarDateX on DateTime {
  /// This value as a stored calendar day (UTC midnight of its own fields).
  DateTime get asCalendarDay => CalendarDate.fromLocalPick(this);
}
