import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/utils/date_utils.dart' as app_date_utils;

void main() {
  group('DateUtils', () {
    test('startOfMonth returns the first day of the month at midnight', () {
      final date = DateTime(2023, 5, 15, 14, 30);
      final start = app_date_utils.DateUtils.startOfMonth(date);
      expect(start.year, 2023);
      expect(start.month, 5);
      expect(start.day, 1);
      expect(start.hour, 0);
      expect(start.minute, 0);
      expect(start.second, 0);
      expect(start.millisecond, 0);
    });

    test('endOfMonth returns the last millisecond of the month', () {
      final date = DateTime(2023, 5, 15);
      final end = app_date_utils.DateUtils.endOfMonth(date);

      // May has 31 days
      expect(end.year, 2023);
      expect(end.month, 5);
      expect(end.day, 31);
      expect(end.hour, 23);
      expect(end.minute, 59);
      expect(end.second, 59);
      expect(end.millisecond, 999);
    });

    test('endOfMonth handles leap years correctly', () {
      final leapYearDate = DateTime(2024, 2, 10);
      final end = app_date_utils.DateUtils.endOfMonth(leapYearDate);

      expect(end.year, 2024);
      expect(end.month, 2);
      expect(end.day, 29);
    });

    test('formatMonth returns YYYY-MM string', () {
      final date = DateTime(2023, 11, 5);
      expect(app_date_utils.DateUtils.formatMonth(date), '2023-11');
    });

    test('parseMonth parses YYYY-MM string correctly', () {
      final date = app_date_utils.DateUtils.parseMonth('2023-09');
      expect(date.year, 2023);
      expect(date.month, 9);
      expect(date.day, 1);
    });

    test('isSameMonth returns true for same month and year', () {
      final date1 = DateTime(2023, 10, 1);
      final date2 = DateTime(2023, 10, 31);
      expect(app_date_utils.DateUtils.isSameMonth(date1, date2), isTrue);
    });

    test('isSameMonth returns false for different months', () {
      final date1 = DateTime(2023, 10, 1);
      final date2 = DateTime(2023, 11, 1);
      expect(app_date_utils.DateUtils.isSameMonth(date1, date2), isFalse);
    });

    test('isSameMonth returns false for different years', () {
      final date1 = DateTime(2023, 10, 1);
      final date2 = DateTime(2024, 10, 1);
      expect(app_date_utils.DateUtils.isSameMonth(date1, date2), isFalse);
    });
  });
}
