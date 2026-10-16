import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';

void main() {
  test('fromLocalPick keeps the picked calendar day as UTC midnight', () {
    final picked = DateTime(2024, 3, 31, 23, 30);
    final stored = CalendarDate.fromLocalPick(picked);
    expect(stored.isUtc, isTrue);
    expect(stored, DateTime.utc(2024, 3, 31));
    expect(
      CalendarDate.fromLocalPick(DateTime.utc(2024, 1, 2, 5)),
      DateTime.utc(2024, 1, 2),
    );
  });

  test('month bounds are half-open UTC intervals', () {
    expect(
      CalendarDate.startOfMonthUtc(DateTime(2024, 2, 15)),
      DateTime.utc(2024, 2, 1),
    );
    expect(
      CalendarDate.endOfMonthUtc(DateTime(2024, 2, 15)),
      DateTime.utc(2024, 3, 1),
    );
    expect(
      CalendarDate.endOfMonthUtc(DateTime(2024, 12, 15)),
      DateTime.utc(2025, 1, 1),
    );
    final lastDay = DateTime.utc(2024, 2, 29);
    expect(lastDay.isBefore(CalendarDate.endOfMonthUtc(lastDay)), isTrue);
  });

  test('day and year bounds', () {
    expect(
      CalendarDate.endOfDayUtc(DateTime(2024, 12, 31)),
      DateTime.utc(2025, 1, 1),
    );
    expect(CalendarDate.startOfYearUtc(2024), DateTime.utc(2024));
    expect(CalendarDate.endOfYearUtc(2024), DateTime.utc(2025));
  });

  test('month keys', () {
    expect(CalendarDate.monthKey(DateTime.utc(2024, 3, 9)), '2024-03');
    expect(CalendarDate.parseMonthKey('2024-03'), DateTime.utc(2024, 3, 1));
  });

  test('toLocalDay and isSameDay', () {
    final stored = DateTime.utc(2024, 5, 6);
    expect(CalendarDate.toLocalDay(stored), DateTime(2024, 5, 6));
    expect(CalendarDate.isSameDay(stored, DateTime(2024, 5, 6, 22)), isTrue);
    expect(DateTime(2024, 5, 6, 12).asCalendarDay, stored);
  });
}
