// The CSV mapping screen with a file loaded: parsing and the column
// analysis run in isolates (compute), so the tests let real time pass
// until the screen shows the file.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/screens/import/csv_import_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/memory_platform_file.dart';
import '../../../helpers/test_database.dart';

Future<void> _pumpScreen(WidgetTester tester, String csv) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final t = TestDatabase();
  addTearDown(t.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(t.db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: CsvImportScreen(
          initialFile: MemoryPlatformFile(
            name: 'bank.csv',
            bytes: utf8.encode(csv),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
}

/// Lets the isolates finish: real time passes until the configuration card
/// is back on screen.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 200; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
    if (find.byKey(const Key('csv_no_header_row')).evaluate().isNotEmpty &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      // One more turn for an analysis started by the last interaction.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      return;
    }
  }
  fail('the CSV screen did not finish loading');
}

void main() {
  testWidgets('a card statement with positive charges shows the income '
      'warning until the sign switch is turned off (Improvement 1)', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      'Date,Description,Amount\n'
      '2026-10-01,Bakery,2.50\n'
      '2026-10-02,Market,20.00\n'
      '2026-10-03,Cinema,12.00\n',
    );
    expect(find.byKey(const Key('csv_all_inflows')), findsOneWidget);
    expect(
      find.textContaining('All 3 amounts would be imported as income'),
      findsOneWidget,
    );

    await tester.tap(find.text('Negative values are outflows'));
    await tester.pump();
    expect(find.byKey(const Key('csv_all_inflows')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a file without header row is shown as such and the switch '
      'reads it the other way', (tester) async {
    await _pumpScreen(
      tester,
      '01.10.2026;Bakery Schmidt;-2,50\n'
      '02.10.2026;Market Hall;-20,00\n',
    );
    final noHeader = find.byKey(const Key('csv_no_header_row'));
    expect(tester.widget<SwitchListTile>(noHeader).value, isTrue);
    // Columns are numbered and both lines are rows of the preview.
    expect(find.text('#1'), findsWidgets);
    expect(find.text('Bakery Schmidt'), findsOneWidget);
    expect(find.text('Market Hall'), findsOneWidget);
    expect(find.byKey(const Key('csv_all_inflows')), findsNothing);

    await tester.tap(noHeader);
    await tester.pump();
    await _settle(tester);
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('csv_no_header_row')))
          .value,
      isFalse,
    );
    // The first line is the header again (old behaviour, by choice).
    expect(find.text('#1'), findsNothing);
    expect(find.text('Bakery Schmidt'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a typed date format is checked and then used', (tester) async {
    await _pumpScreen(
      tester,
      'Date,Description,Amount\n'
      '2026-10-01,Bakery,-2.50\n'
      '2026-10-02,Salary,2000.00\n',
    );
    await tester.tap(find.byKey(const Key('csv_other_date_format')));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('csv_custom_date_format'));
    await tester.enterText(field, 'MM/yyyy');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('This pattern cannot be used'), findsOneWidget);

    await tester.enterText(field, 'MMM d, yyyy');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('csv_custom_date_format')), findsNothing);
    expect(find.text('MMM d, yyyy'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
