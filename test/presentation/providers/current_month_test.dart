import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/widgets/home/dashboard_stats_widget.dart';

/// The default month follows the calendar (resume, midnight) without
/// touching a month the user navigated to.
void main() {
  late DateTime now;
  late ProviderContainer container;

  setUp(() {
    now = DateTime(2026, 10, 31, 23, 50);
    container = ProviderContainer(
      overrides: [
        todayProvider.overrideWith((ref) => TodayController(clock: () => now)),
      ],
    );
  });

  tearDown(() => container.dispose());

  void resume() => container.read(todayProvider.notifier).refresh();

  test('the default month moves on when the app resumes in a new month', () {
    expect(container.read(currentMonthProvider), DateTime.utc(2026, 10));
    expect(container.read(selectedBudgetMonthProvider), DateTime.utc(2026, 10));
    expect(container.read(selectedHomeMonthProvider), DateTime.utc(2026, 10));

    now = DateTime(2026, 11, 1, 0, 5);
    resume();

    expect(container.read(todayProvider), DateTime.utc(2026, 11, 1));
    expect(container.read(selectedBudgetMonthProvider), DateTime.utc(2026, 11));
    expect(container.read(selectedHomeMonthProvider), DateTime.utc(2026, 11));
  });

  test('a month the user navigated to is left alone', () {
    container.read(selectedBudgetMonthProvider.notifier).state = DateTime.utc(
      2026,
      8,
    );
    container.read(selectedHomeMonthProvider.notifier).state = DateTime.utc(
      2026,
      9,
    );
    now = DateTime(2026, 11, 1, 0, 5);
    resume();
    expect(container.read(selectedBudgetMonthProvider), DateTime.utc(2026, 8));
    expect(container.read(selectedHomeMonthProvider), DateTime.utc(2026, 9));
  });

  test('a resume on the same day changes nothing', () {
    container.read(selectedBudgetMonthProvider);
    now = DateTime(2026, 10, 31, 23, 55);
    resume();
    expect(container.read(selectedBudgetMonthProvider), DateTime.utc(2026, 10));
  });

  testWidgets('midnight on the 1st moves the month while the app is open', (
    tester,
  ) async {
    // The test binding's clock advances with pump(duration).
    final realStart = tester.binding.clock.now();
    final start = DateTime(2026, 10, 31, 23, 50);
    DateTime clock() =>
        start.add(tester.binding.clock.now().difference(realStart));
    final c = ProviderContainer(
      overrides: [
        todayProvider.overrideWith((ref) => TodayController(clock: clock)),
      ],
    );
    expect(c.read(selectedBudgetMonthProvider), DateTime.utc(2026, 10));
    await tester.pump(const Duration(minutes: 5));
    expect(c.read(selectedBudgetMonthProvider), DateTime.utc(2026, 10));
    await tester.pump(const Duration(minutes: 6));
    expect(c.read(todayProvider), DateTime.utc(2026, 11, 1));
    expect(c.read(selectedBudgetMonthProvider), DateTime.utc(2026, 11));
    // Before the pending-timer check: disposing cancels the midnight timer.
    c.dispose();
  });
}
