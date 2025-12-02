import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/month_selector.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

void main() {
  testWidgets('MonthSelector displays current month and navigates', (tester) async {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final previousMonth = DateTime(now.year, now.month - 1);
    final nextMonth = DateTime(now.year, now.month + 1);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MonthSelector()),
        ),
      ),
    );

    // Check current month display
    expect(find.text(DateFormat.yMMMM().format(currentMonth)), findsOneWidget);

    // Tap previous
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();

    expect(find.text(DateFormat.yMMMM().format(previousMonth)), findsOneWidget);

    // Tap next twice (back to current, then next)
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(find.text(DateFormat.yMMMM().format(currentMonth)), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(find.text(DateFormat.yMMMM().format(nextMonth)), findsOneWidget);
  });
}
