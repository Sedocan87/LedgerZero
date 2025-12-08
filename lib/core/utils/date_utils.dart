import 'package:intl/intl.dart';

/// Utilities for common date operations in LedgerZero.
class DateUtils {
  static final _monthFormat = DateFormat('yyyy-MM');

  /// Returns the start of the month for the given date.
  /// Example: 2023-05-15 -> 2023-05-01 00:00:00
  static DateTime startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// Returns the end of the month for the given date (last millisecond).
  /// Example: 2023-05-15 -> 2023-05-31 23:59:59.999
  static DateTime endOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 1).subtract(const Duration(milliseconds: 1));
  }

  /// Formats a date as YYYY-MM.
  static String formatMonth(DateTime date) {
    return _monthFormat.format(date);
  }

  /// Parses a YYYY-MM string to a DateTime (start of month).
  static DateTime parseMonth(String monthStr) {
    return _monthFormat.parse(monthStr);
  }

  /// Returns true if two dates are in the same month and year.
  static bool isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }
}
