import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/reports/reports_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';

void main() {
  testWidgets('Reports refresh after a new transaction', (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final t = TestDatabase();
    await t.addAccount(id: 'a');
    await t.payees.createPayee(const Payee(id: 'p1', name: 'Bakery'));
    await t.payees.createPayee(const Payee(id: 'p2', name: 'Florist'));
    await t.addTransaction(
      accountId: 'a',
      amount: -1200,
      payeeId: 'p1',
      date: CalendarDate.today(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          appFormatterProvider.overrideWithValue(
            AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.'),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: ReportsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bakery'), findsWidgets);
    expect(find.text('Florist'), findsNothing);

    // Saved elsewhere (e.g. the transaction form): Reports follow.
    await tester.runAsync(
      () => t.addTransaction(
        accountId: 'a',
        amount: -800,
        payeeId: 'p2',
        date: CalendarDate.today(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Florist'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await t.close();
  });
}
