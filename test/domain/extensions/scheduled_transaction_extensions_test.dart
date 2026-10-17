import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/extensions/scheduled_transaction_extensions.dart';

/// Run this file also with `TZ=Europe/Berlin` and `TZ=America/New_York`:
/// the results must not depend on the host time zone.
void main() {
  ScheduledTransaction schedule(
    DateTime nextDate,
    RecurrenceFrequency frequency, {
    int interval = 1,
    int? anchorDay,
    DateTime? endDate,
    int? occurrenceCount,
  }) => ScheduledTransaction(
    id: 's',
    nextDate: nextDate,
    frequency: frequency,
    interval: interval,
    anchorDay: anchorDay,
    endDate: endDate,
    occurrenceCount: occurrenceCount,
  );

  /// The next dates of [s] after repeatedly advancing it [count] times.
  List<DateTime?> sequence(ScheduledTransaction s, int count) {
    final dates = <DateTime?>[];
    var current = s;
    for (var i = 0; i < count; i++) {
      current = current.advanced();
      dates.add(current.nextDate);
    }
    return dates;
  }

  group('calculateNextOccurrenceDate', () {
    test('returns null if nextDate is null', () {
      const transaction = ScheduledTransaction(id: '1', nextDate: null);
      expect(transaction.calculateNextOccurrenceDate(), isNull);
    });

    test('daily recurrence adds interval days', () {
      final s = schedule(
        DateTime.utc(2023, 1, 1),
        RecurrenceFrequency.daily,
        interval: 2,
      );
      expect(s.calculateNextOccurrenceDate(), DateTime.utc(2023, 1, 3));
    });

    test('weekly recurrence adds interval weeks', () {
      final s = schedule(
        DateTime.utc(2023, 1, 1),
        RecurrenceFrequency.weekly,
        interval: 2,
      );
      expect(s.calculateNextOccurrenceDate(), DateTime.utc(2023, 1, 15));
    });

    test('daily crosses month and year ends', () {
      expect(
        schedule(
          DateTime.utc(2023, 12, 31),
          RecurrenceFrequency.daily,
        ).calculateNextOccurrenceDate(),
        DateTime.utc(2024, 1, 1),
      );
      expect(
        schedule(
          DateTime.utc(2024, 2, 28),
          RecurrenceFrequency.daily,
        ).calculateNextOccurrenceDate(),
        DateTime.utc(2024, 2, 29),
      );
    });

    test('monthly recurrence handles standard months', () {
      final s = schedule(
        DateTime.utc(2023, 1, 15),
        RecurrenceFrequency.monthly,
      );
      expect(s.calculateNextOccurrenceDate(), DateTime.utc(2023, 2, 15));
    });

    test('monthly clamps Jan 31 -> Feb 28', () {
      final s = schedule(
        DateTime.utc(2023, 1, 31),
        RecurrenceFrequency.monthly,
      );
      expect(s.calculateNextOccurrenceDate(), DateTime.utc(2023, 2, 28));
    });

    test('monthly clamps Jan 31 -> Feb 29 in a leap year', () {
      final s = schedule(
        DateTime.utc(2024, 1, 31),
        RecurrenceFrequency.monthly,
      );
      expect(s.calculateNextOccurrenceDate(), DateTime.utc(2024, 2, 29));
    });

    test('monthly returns to the anchor day after a short month', () {
      final s = schedule(
        DateTime.utc(2024, 2, 29),
        RecurrenceFrequency.monthly,
        anchorDay: 31,
      );
      expect(s.calculateNextOccurrenceDate(), DateTime.utc(2024, 3, 31));
    });

    test('monthly with interval > 1 crosses the year and clamps', () {
      final s = schedule(
        DateTime.utc(2023, 11, 30),
        RecurrenceFrequency.monthly,
        interval: 3,
      );
      expect(s.calculateNextOccurrenceDate(), DateTime.utc(2024, 2, 29));
      final s2 = schedule(
        DateTime.utc(2023, 10, 31),
        RecurrenceFrequency.monthly,
        interval: 14,
      );
      expect(s2.calculateNextOccurrenceDate(), DateTime.utc(2024, 12, 31));
    });

    test('yearly recurrence adds interval years', () {
      final s = schedule(DateTime.utc(2023, 5, 10), RecurrenceFrequency.yearly);
      expect(s.calculateNextOccurrenceDate(), DateTime.utc(2024, 5, 10));
      final s2 = schedule(
        DateTime.utc(2023, 5, 10),
        RecurrenceFrequency.yearly,
        interval: 3,
      );
      expect(s2.calculateNextOccurrenceDate(), DateTime.utc(2026, 5, 10));
    });

    test('yearly Feb 29 -> Feb 28 in a common year', () {
      final s = schedule(DateTime.utc(2024, 2, 29), RecurrenceFrequency.yearly);
      expect(s.calculateNextOccurrenceDate(), DateTime.utc(2025, 2, 28));
    });

    test('yearly Feb 29 with interval 4 stays on Feb 29', () {
      final s = schedule(
        DateTime.utc(2024, 2, 29),
        RecurrenceFrequency.yearly,
        interval: 4,
      );
      expect(s.calculateNextOccurrenceDate(), DateTime.utc(2028, 2, 29));
    });

    test('returns null if the next date is after the end date', () {
      final s = schedule(
        DateTime.utc(2023, 1, 1),
        RecurrenceFrequency.daily,
        endDate: DateTime.utc(2023, 1, 1),
      );
      expect(s.calculateNextOccurrenceDate(), isNull);
    });

    test('returns the date if it is on the end date', () {
      final s = schedule(
        DateTime.utc(2023, 1, 1),
        RecurrenceFrequency.daily,
        endDate: DateTime.utc(2023, 1, 2),
      );
      expect(s.calculateNextOccurrenceDate(), DateTime.utc(2023, 1, 2));
    });

    test(
      'end date given as a local DateTime is compared as a calendar day',
      () {
        final s = schedule(
          DateTime.utc(2023, 1, 1),
          RecurrenceFrequency.daily,
          endDate: DateTime(2023, 1, 2, 0, 0),
        );
        expect(s.calculateNextOccurrenceDate(), DateTime.utc(2023, 1, 2));
      },
    );

    test('results are always UTC midnight', () {
      for (final f in RecurrenceFrequency.values) {
        final next = schedule(
          DateTime(2024, 3, 30, 23, 30),
          f,
        ).calculateNextOccurrenceDate()!;
        expect(next.isUtc, isTrue, reason: '$f');
        expect(
          [next.hour, next.minute, next.second, next.millisecond],
          [0, 0, 0, 0],
          reason: '$f',
        );
      }
    });
  });

  group('DST boundaries', () {
    // Europe/Berlin: 2024-03-31 (spring forward), 2024-10-27 (fall back).
    // America/New_York: 2024-03-10 (spring forward), 2024-11-03 (fall back).
    final boundaries = <String, DateTime>{
      'Europe/Berlin spring': DateTime.utc(2024, 3, 31),
      'Europe/Berlin fall': DateTime.utc(2024, 10, 27),
      'America/New_York spring': DateTime.utc(2024, 3, 10),
      'America/New_York fall': DateTime.utc(2024, 11, 3),
    };

    for (final entry in boundaries.entries) {
      final b = entry.value;

      test('${entry.key}: daily steps hit every calendar day', () {
        final start = DateTime.utc(b.year, b.month, b.day - 3);
        final expected = [
          for (var i = 1; i <= 6; i++)
            DateTime.utc(start.year, start.month, start.day + i),
        ];
        expect(
          sequence(schedule(start, RecurrenceFrequency.daily), 6),
          expected,
        );
      });

      test('${entry.key}: weekly step lands on the same weekday', () {
        final start = DateTime.utc(b.year, b.month, b.day - 2);
        final next = schedule(
          start,
          RecurrenceFrequency.weekly,
        ).calculateNextOccurrenceDate()!;
        expect(next, DateTime.utc(start.year, start.month, start.day + 7));
        expect(next.weekday, start.weekday);
      });

      test('${entry.key}: local DateTime inputs keep their calendar day', () {
        // Local midnight and a late-evening local time just before the
        // boundary: neither may shift a day.
        for (final hour in [0, 1, 23]) {
          final local = DateTime(b.year, b.month, b.day - 1, hour, 30);
          expect(local.isUtc, isFalse);
          expect(
            schedule(
              local,
              RecurrenceFrequency.daily,
            ).calculateNextOccurrenceDate(),
            DateTime.utc(b.year, b.month, b.day),
            reason: 'daily from local $local',
          );
          expect(
            schedule(
              local,
              RecurrenceFrequency.weekly,
            ).calculateNextOccurrenceDate(),
            DateTime.utc(b.year, b.month, b.day + 6),
            reason: 'weekly from local $local',
          );
          expect(
            schedule(
              local,
              RecurrenceFrequency.daily,
              interval: 2,
            ).calculateNextOccurrenceDate(),
            DateTime.utc(b.year, b.month, b.day + 1),
            reason: 'every 2 days from local $local',
          );
        }
      });

      test('${entry.key}: weekly sequence over 10 weeks stays on weekday', () {
        final start = DateTime(b.year, b.month, b.day - 20); // local
        final dates = sequence(schedule(start, RecurrenceFrequency.weekly), 10);
        for (var i = 0; i < dates.length; i++) {
          expect(
            dates[i],
            DateTime.utc(start.year, start.month, start.day + 7 * (i + 1)),
          );
        }
      });
    }
  });

  group('advanced', () {
    test(
      'month-end sequence Jan 31 -> Feb 29 -> Mar 31 -> Apr 30 -> May 31',
      () {
        final s = schedule(
          DateTime.utc(2024, 1, 31),
          RecurrenceFrequency.monthly,
        );
        expect(sequence(s, 4), [
          DateTime.utc(2024, 2, 29),
          DateTime.utc(2024, 3, 31),
          DateTime.utc(2024, 4, 30),
          DateTime.utc(2024, 5, 31),
        ]);
      },
    );

    test('month-end sequence in a common year (Feb 28)', () {
      final s = schedule(
        DateTime.utc(2023, 1, 31),
        RecurrenceFrequency.monthly,
      );
      expect(sequence(s, 3), [
        DateTime.utc(2023, 2, 28),
        DateTime.utc(2023, 3, 31),
        DateTime.utc(2023, 4, 30),
      ]);
    });

    test('pins the anchor day of monthly schedules', () {
      final s = schedule(
        DateTime.utc(2024, 1, 31),
        RecurrenceFrequency.monthly,
      ).advanced();
      expect(s.anchorDay, 31);
      expect(s.nextDate, DateTime.utc(2024, 2, 29));
    });

    test('an explicit anchor day wins over the day of nextDate', () {
      final s = schedule(
        DateTime.utc(2024, 4, 30),
        RecurrenceFrequency.monthly,
        anchorDay: 31,
      );
      expect(sequence(s, 2), [
        DateTime.utc(2024, 5, 31),
        DateTime.utc(2024, 6, 30),
      ]);
    });

    test('yearly Feb 29 -> Feb 28 (x3) -> Feb 29 in the next leap year', () {
      final s = schedule(DateTime.utc(2024, 2, 29), RecurrenceFrequency.yearly);
      expect(sequence(s, 4), [
        DateTime.utc(2025, 2, 28),
        DateTime.utc(2026, 2, 28),
        DateTime.utc(2027, 2, 28),
        DateTime.utc(2028, 2, 29),
      ]);
    });

    test('interval > 1 month-end sequence', () {
      final s = schedule(
        DateTime.utc(2024, 1, 31),
        RecurrenceFrequency.monthly,
        interval: 2,
      );
      expect(sequence(s, 3), [
        DateTime.utc(2024, 3, 31),
        DateTime.utc(2024, 5, 31),
        DateTime.utc(2024, 7, 31),
      ]);
    });

    test('decrements the occurrence count', () {
      final s = schedule(
        DateTime.utc(2024, 1, 1),
        RecurrenceFrequency.monthly,
        occurrenceCount: 3,
      ).advanced();
      expect(s.occurrenceCount, 2);
      expect(s.nextDate, DateTime.utc(2024, 2, 1));
    });

    test('the last counted occurrence finishes the schedule', () {
      final s = schedule(
        DateTime.utc(2024, 1, 1),
        RecurrenceFrequency.monthly,
        occurrenceCount: 1,
      ).advanced();
      expect(s.nextDate, isNull);
      expect(s.occurrenceCount, 0);
      expect(s.isFinished, isTrue);
    });

    test('passing the end date finishes the schedule', () {
      final s = schedule(
        DateTime.utc(2024, 1, 1),
        RecurrenceFrequency.monthly,
        endDate: DateTime.utc(2024, 1, 20),
      ).advanced();
      expect(s.nextDate, isNull);
      expect(s.occurrenceCount, isNull);
    });

    test('a finished schedule is returned unchanged', () {
      const s = ScheduledTransaction(id: 's', occurrenceCount: 0);
      expect(s.advanced(), s);
    });

    test('keeps the other fields', () {
      final s = ScheduledTransaction(
        id: 's',
        accountId: 'a',
        payeeId: 'p',
        categoryId: 'c',
        amount: -1234,
        memo: 'Rent',
        autoApprove: true,
        frequency: RecurrenceFrequency.weekly,
        nextDate: DateTime.utc(2024, 1, 1),
      ).advanced();
      expect(s.accountId, 'a');
      expect(s.payeeId, 'p');
      expect(s.categoryId, 'c');
      expect(s.amount, -1234);
      expect(s.memo, 'Rent');
      expect(s.autoApprove, isTrue);
      expect(s.anchorDay, isNull);
      expect(s.nextDate, DateTime.utc(2024, 1, 8));
    });
  });

  group('RecurrenceMath', () {
    test('daysInMonth', () {
      expect(RecurrenceMath.daysInMonth(2024, 2), 29);
      expect(RecurrenceMath.daysInMonth(2023, 2), 28);
      expect(RecurrenceMath.daysInMonth(2100, 2), 28);
      expect(RecurrenceMath.daysInMonth(2000, 2), 29);
      expect(RecurrenceMath.daysInMonth(2024, 4), 30);
      expect(RecurrenceMath.daysInMonth(2024, 12), 31);
    });

    test('step with a non-positive interval moves one period', () {
      expect(
        RecurrenceMath.step(
          DateTime.utc(2024, 1, 1),
          RecurrenceFrequency.daily,
          0,
        ),
        DateTime.utc(2024, 1, 2),
      );
    });
  });
  group('occurrencesBetween', () {
    final oct = DateTime.utc(2026, 10, 1);
    final nov = DateTime.utc(2026, 11, 1);

    test('lists every weekly occurrence inside the range', () {
      final s = schedule(DateTime.utc(2026, 9, 24), RecurrenceFrequency.weekly);
      expect(s.occurrencesBetween(oct, nov), [
        DateTime.utc(2026, 10, 1),
        DateTime.utc(2026, 10, 8),
        DateTime.utc(2026, 10, 15),
        DateTime.utc(2026, 10, 22),
        DateTime.utc(2026, 10, 29),
      ]);
    });

    test('excludes the exclusive end', () {
      final s = schedule(nov, RecurrenceFrequency.monthly);
      expect(s.occurrencesBetween(oct, nov), isEmpty);
    });

    test('reaches a later month and keeps the anchor day', () {
      final s = schedule(
        DateTime.utc(2026, 1, 31),
        RecurrenceFrequency.monthly,
      );
      expect(
        s.occurrencesBetween(
          DateTime.utc(2026, 2, 1),
          DateTime.utc(2026, 4, 1),
        ),
        [DateTime.utc(2026, 2, 28), DateTime.utc(2026, 3, 31)],
      );
    });

    test('respects the occurrence count and the end date', () {
      final counted = schedule(
        DateTime.utc(2026, 10, 1),
        RecurrenceFrequency.weekly,
        occurrenceCount: 2,
      );
      expect(counted.occurrencesBetween(oct, nov), [
        DateTime.utc(2026, 10, 1),
        DateTime.utc(2026, 10, 8),
      ]);

      final ending = schedule(
        DateTime.utc(2026, 10, 1),
        RecurrenceFrequency.weekly,
        endDate: DateTime.utc(2026, 10, 10),
      );
      expect(ending.occurrencesBetween(oct, nov), [
        DateTime.utc(2026, 10, 1),
        DateTime.utc(2026, 10, 8),
      ]);
    });

    test('is empty for a finished schedule', () {
      const s = ScheduledTransaction(id: 's');
      expect(s.occurrencesBetween(oct, nov), isEmpty);
    });
  });
}
